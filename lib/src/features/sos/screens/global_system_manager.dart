import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemSound
import 'dart:async'; // Added
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geocoding/geocoding.dart'; // Removed 
import 'package:url_launcher/url_launcher.dart'; // Added
import 'package:intl/intl.dart';
import 'package:carenow/l10n/app_localizations.dart';
import '../../auth/services/auth_provider.dart';


import '../../auth/models/user_model.dart';
import '../services/sos_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/notification_service.dart'; // Fixed Path
import '../../appointments/screens/live_queue_screen.dart'; // Added
// import '../../../../main.dart'; // No longer needed with Overlay approach

class GlobalSystemManager extends StatefulWidget {
  final Widget child;
  const GlobalSystemManager({super.key, required this.child});

  @override
  State<GlobalSystemManager> createState() => _GlobalSystemManagerState();
}

class _GlobalSystemManagerState extends State<GlobalSystemManager> {
  final SOSService _sosService = SOSService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  void dispose() {
    SoundService.stopLoop();
    super.dispose();
  }

  // Track state
  Set<String> _alertedQueueIds = {};
  Set<String> _upNextAlertIds = {}; // Track "Up Next" alerts
  Map<String, dynamic>? _upNextApt; // Data for "Up Next" popup
  QueryDocumentSnapshot? _selectedSOSDoc; // Current SOS being viewed
  
  // Caregiver Specific State
  final Set<String> _caregiverSilencedIds = {};

  // Staff Specific State
  final Set<String> _staffSilencedIds = {};
  final Set<String> _playedSoundIds = {}; // Track IDs we've already alerted for
  
  // Streams to avoid flickering on rebuild
  Stream<QuerySnapshot<Map<String, dynamic>>>? _elderlySOSStream;
  String? _currentElderlyId;

  void _triggerBriefAlarm() {
     SoundService.playSOSLoop();
     // "play once or twice" -> Stop after ~5 seconds
     Future.delayed(const Duration(seconds: 5), () {
        SoundService.stopLoop();
     });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final l10n = AppLocalizations.of(context)!;

    return Stack(
      children: [
        // 1. The Main App
        widget.child,

        // 2. Global Logic & Overlays
        if (user != null) ...[
          // STAFF: SOS MONITOR
          if (user.role == UserRole.hospitalStaff)
            _buildStaffSOSMonitor(user),

          // CAREGIVER: ELDERLY SOS MONITOR
          if (user.role == UserRole.caregiver)
            _buildCaregiverSOSMonitor(user),

          // ELDERLY/PATIENT: QUEUE MONITOR
          _buildQueueMonitor(user),
          
          // UP NEXT POPUP
          if (_upNextApt != null)
             _buildUpNextPopup(_upNextApt!),

          // 3. SOS Detail Overlay (Replaces Dialog)
          if (_selectedSOSDoc != null)
             _SOSDetailOverlay(
               sosDoc: _selectedSOSDoc!,
               sosService: _sosService,
               onClose: () => setState(() => _selectedSOSDoc = null),
             ),
        ],
      ],
    );
  }

  // 🔹 STAFF PORTAL SOS VISIBILITY
  Widget _buildStaffSOSMonitor(User user) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot>(
      stream: _sosService.getPendingSOSStream(),
      builder: (context, snapshot) {
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Stop sound if no data
            WidgetsBinding.instance.addPostFrameCallback((_) {
               // Only stop if sound was playing for STAFF purposes. 
               // (SoundService handles one stream, so stopLoop is generally safe here if no alerts)
               // However, ideally checking if WE started it is better, but SoundService is singleton.
               // We will rely on the fact that if this rebuilds with no data, we should stop alarm.
               // We also clear silenced IDs so new alerts trigger sound again.
               if (_staffSilencedIds.isNotEmpty) {
                  // Keep them? Or clear? 
                  // If list is empty, clear.
               }
            });
            return const SizedBox.shrink();
        }

        final sosList = snapshot.data!.docs;
        
        // Filter out silenced
        final activeUnsilenced = sosList.where((doc) => !_staffSilencedIds.contains(doc.id)).toList();
        
        // SOUND LOGIC: Loop as long as there are active unsilenced alerts
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (activeUnsilenced.isNotEmpty) {
               SoundService.playSOSLoop();
            } else {
               SoundService.stopLoop();
            }
        });

        // "lightweight emergency notification indicator... with a clearly visible View button"
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            elevation: 4,
            color: Colors.transparent, // Transparent to let shadow show but keep lightweight
            child: Container(
               margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               decoration: BoxDecoration(
                 color: Colors.redAccent,
                 borderRadius: BorderRadius.circular(30), // Pill shape / Lightweight
                 boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26, offset: Offset(0, 2))],
               ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Icon(Icons.warning_amber_rounded, color: Colors.white),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       l10n.activeEmergencies(sosList.length.toString()),
                       style: const TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                         fontSize: 14,
                       ),
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   const SizedBox(width: 8),
                   // View Button
                   ElevatedButton(
                      onPressed: () {
                          // Toggle visibility logic? Or just open the first one. 
                          // User said "View button must then open the emergency alert details"
                          setState(() {
                             _selectedSOSDoc = sosList.first;
                          });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, 
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(60, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap
                      ),
                      child: Text(l10n.view, style: const TextStyle(fontSize: 12)),
                   ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🔹 CAREGIVER ALERT SYSTEM (Redesigned: Non-Blocking & Detailed)
  Widget _buildCaregiverSOSMonitor(User user) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _sosService.getCaregiverSOSStream(user.linkedElderlyIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
           WidgetsBinding.instance.addPostFrameCallback((_) => SoundService.stopLoop());
           return const SizedBox.shrink();
        }

        // Standard stable sorting
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final tA = (a.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
          final tB = (b.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
          return tB.compareTo(tA);
        });

        // Filter and Map
        final activeAlerts = docs
            .map((d) => d.data())
            .where((data) {
                // Ignore silenced
                if (_caregiverSilencedIds.contains(data['sosId'])) return false;
                // Ignore older than 24h
                final ts = data['timestamp'] as Timestamp?;
                if (ts != null && DateTime.now().difference(ts.toDate()).inHours > 24) return false;
                return true;
            })
            .toList();

        if (activeAlerts.isEmpty) {
           WidgetsBinding.instance.addPostFrameCallback((_) => SoundService.stopLoop());
           return const SizedBox.shrink();
        }

        // Play Sound if we have active alerts
        WidgetsBinding.instance.addPostFrameCallback((_) => SoundService.playSOSLoop());

        // Display Alert (Top Overlay, Non-Blocking)
        final alert = activeAlerts.first;
        final patientId = alert['userId'];
        final status = (alert['status'] as String).toUpperCase();
        
        // Find patient details from AuthProvider (cached)
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final patient = auth.linkedProfiles.cast<User?>().firstWhere(
           (p) => p?.id == patientId, 
           orElse: () => null
        );

        final patientName = patient?.name ?? "Unknown Patient";
        final patientCode = patient?.uniqueId ?? patientId ?? "N/A";
        
        final Timestamp? ts = alert['timestamp'];
        final timeStr = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : 'Now';

        Color statusColor = Colors.yellowAccent;
        String statusText = l10n.loading; // Default to Pending/Loading
        if (status == 'ACCEPTED' || status == 'APPROVED') {
           statusText = l10n.approved;
        } else if (status == 'RESOLVED') {
           statusText = l10n.emergencyResolved;
        }

        return Positioned(
          top: 50, // Below standard app bars
          left: 16,
          right: 16,
          child: Material(
            elevation: 20,
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4)
                  )
                ]
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Padding(
                         padding: EdgeInsets.only(top: 4.0),
                         child: Icon(Icons.warning, color: Colors.white, size: 36),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Row(
                                children: [
                                  Expanded(child: Text(l10n.emergencyAlertTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.1))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                    child: Text(statusText, style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text("${l10n.patientLabel}: $patientName", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                              Text("${l10n.code}: $patientCode", style: const TextStyle(color: Colors.yellowAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                              Text("${l10n.timeLabel}: $timeStr", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                           ],
                         ),
                       )
                     ],
                   ),
                   const SizedBox(height: 12),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: () {
                          // Silence Logic
                          setState(() {
                             _caregiverSilencedIds.add(alert['sosId']);
                             SoundService.stopLoop();
                          });
                       },
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.white, 
                         foregroundColor: Colors.red,
                         elevation: 0,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                       ),
                       child: Text(l10n.silenceAlarm, style: const TextStyle(fontWeight: FontWeight.bold)),
                     ),
                   )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🔹 UP NEXT POPUP (Refined to be Non-Blocking)
  Widget _buildUpNextPopup(Map<String, dynamic> apt) {
      final l10n = AppLocalizations.of(context)!;
      // Use a top banner/card that doesn't block the whole screen
      return Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
               // Tap stops sound and deep links
               SoundService.stopLoop();
               setState(() => _upNextApt = null);
               Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveQueueScreen()));
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                border: Border.all(color: Colors.purple, width: 2)
              ),
              child: Row(
                children: [
                   const Icon(Icons.notifications_active, color: Colors.purple, size: 40),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(l10n.upNextAlert, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                         Text("${l10n.token}: ${apt['tokenNumber']} - ${apt['doctorName'] ?? 'Doctor'}", style: const TextStyle(fontWeight: FontWeight.w500)),
                       ],
                     ),
                   ),
                   const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      );
  }

  // 🔹 ELDERLY GLOBAL SOS MONITOR
  Widget _buildElderlySOSMonitor(User user) {
    if (_currentElderlyId != user.id) {
       _currentElderlyId = user.id;
       _elderlySOSStream = _sosService.getUserSOSStream(user.id);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _elderlySOSStream,
      builder: (context, snapshot) {
         if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox.shrink();
         }

         // Sort locally to handle documents with null (pending) timestamps
         final docs = snapshot.data!.docs.toList();
         docs.sort((a, b) {
           final tA = (a.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
           final tB = (b.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
           return tB.compareTo(tA);
         });

         final sos = docs.first.data();
         final status = (sos['status'] as String).toUpperCase();
         final responseTime = sos['responseTimestamp'] as Timestamp?;
         final timestamp = sos['timestamp'] as Timestamp?;
         final l10n = AppLocalizations.of(context)!;
         
         // 1. PENDING STATE
         if (status == 'PENDING' || status == 'REQUESTED') {
            return Positioned(
              top: 85, // Below app bar
              left: 16,
              right: 16,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Row(
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.emergency, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("Signal Received. Help Requested.", style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
         }

         // 2. ACCEPTED / APPROVED / RESOLVED STATE
         if (status == 'ACCEPTED' || status == 'APPROVED' || status == 'RESOLVED') {
            final effectiveTime = responseTime?.toDate() ?? DateTime.now();
            final diff = DateTime.now().difference(effectiveTime).abs().inMinutes;

            if (diff < 60) {
              return Positioned(
                top: 85, // Below app bar
                left: 16,
                right: 16,
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l10n.approved, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                Text("Staff are responding. Help is on the way.", style: const TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(
                            "${60 - diff}m",
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
         }
         return const SizedBox.shrink();
      }
    );
  }

  // 🔹 QUEUE MONITOR (Updated)
  Widget _buildQueueMonitor(User user) {
    final l10n = AppLocalizations.of(context)!; 
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: user.id)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
         if (!snapshot.hasData) return const SizedBox.shrink();

         final docs = snapshot.data!.docs;
         
         for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final currentToken = data['currentToken'] ?? 0;
            final myToken = data['tokenNumber'] ?? 0;
            final diff = myToken - currentToken;

            // Nearing logic 
            if (diff > 0 && diff <= 2) {
               // "Up Next" Logic (Diff == 1)
               if (diff == 1 && !_upNextAlertIds.contains(doc.id)) {
                   // Side effects must be separate
                   WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (!_upNextAlertIds.contains(doc.id)) {
                           setState(() {
                             _upNextAlertIds.add(doc.id);
                             _upNextApt = data; // Show Global Popup
                           });
                           SoundService.playQueueLoop(); // Alarm sound
                           // System Notification
                           NotificationService().showLocalNotification(
                              title: "Up Next!",
                              body: "You are next for ${data['doctorName'] ?? 'Doctor'}. Token $myToken.",
                              payload: 'live_queue',
                           );
                       }
                   });
               }
            }
         }

         return const SizedBox.shrink();
      }
    );
  }
}

// ---------------------------------------------------------------------------
// 🔹 SOS DETAIL OVERLAY (Replaces Dialog)
// ---------------------------------------------------------------------------
class _SOSDetailOverlay extends StatefulWidget {
  final QueryDocumentSnapshot sosDoc;
  final SOSService sosService;
  final VoidCallback onClose;

  const _SOSDetailOverlay({required this.sosDoc, required this.sosService, required this.onClose});

  @override
  State<_SOSDetailOverlay> createState() => _SOSDetailOverlayState();
}

class _SOSDetailOverlayState extends State<_SOSDetailOverlay> {
  String? _patientName;
  String? _patientId;
  late DocumentSnapshot _currentDocSnapshot;

  @override
  void initState() {
    super.initState();
    _currentDocSnapshot = widget.sosDoc;
    _fetchDetails();
  }
  
  // Refetch if doc changes (though widget usually rebuilds)
  @override
  void didUpdateWidget(_SOSDetailOverlay oldWidget) {
     super.didUpdateWidget(oldWidget);
     if (oldWidget.sosDoc.id != widget.sosDoc.id) {
        _currentDocSnapshot = widget.sosDoc;
        _fetchDetails();
     }
  }

  void _fetchDetails() async {
    final data = widget.sosDoc.data() as Map<String, dynamic>;

    // 1. Fetch Patient Details
    try {
      final userId = data['userId'];
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        if (mounted) {
           setState(() {
             _patientName = userData['name'] ?? "Unknown";
             _patientId = userData['uniqueId'] ?? userData['id'] ?? "Unknown";
           });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _patientName = "Error fetching user");
    }

    // 2. Fetch Address (Reverse Geocoding) - DISABLED per requirement
    // _updateAddress(data);
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Watch status
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.sosDoc.reference.snapshots(),
      builder: (context, snapshot) {
        
        // Handle stream data
        if (snapshot.hasData && snapshot.data!.exists) {
           final data = snapshot.data!.data() as Map<String, dynamic>;
           if (data['status'] != 'PENDING') {
              // Status changed, close overlay via callback
              // Use postframe to avoid render error
              WidgetsBinding.instance.addPostFrameCallback((_) => widget.onClose());
           } else {
              // Update address if location changed - DISABLED
              // _updateAddress(data);
           }
           _currentDocSnapshot = snapshot.data!;
        } else if (snapshot.hasData && !snapshot.data!.exists) {
           // Deleted
           WidgetsBinding.instance.addPostFrameCallback((_) => widget.onClose());
        }

        final data = _currentDocSnapshot.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        final timeStr = timestamp != null ? DateFormat('hh:mm a').format(timestamp) : 'Now';



        // "non-blocking overlay or side panel... without freezing, dimming, disabling"
        // We use Positioned (NOT .fill) and NO background container.
        return Positioned(
           top: 70, // Below the floating banner
           right: 16, // Docked to right side like a panel? Or just standard overlay. 
           left: 16, // Keep it readable.
           child: Material(
             elevation: 8,
             color: Colors.transparent,
             child: Container(
                  constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 2)]
                  ),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        // Header
                        Container(
                           padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                           decoration: const BoxDecoration(
                             color: Colors.red,
                             borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                           ),
                           child: Row(
                             children: [
                               const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                               const SizedBox(width: 12),
                               Text(l10n.emergencyAlertTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                               const Spacer(),
                               IconButton(
                                 icon: const Icon(Icons.close, color: Colors.white),
                                 padding: EdgeInsets.zero,
                                 constraints: const BoxConstraints(),
                                 onPressed: widget.onClose,
                               )
                             ],
                           ),
                        ),
                        
                        // Content (Flexible for scrolling if content is long, but constrained max height)
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 _detailRow("${l10n.patientName}:", _patientName ?? l10n.loading),
                                 _detailRow("${l10n.patientId}:", _patientId ?? l10n.loading),
                                 _detailRow("${l10n.triggeredBy}:", data['triggeredBy'] ?? 'Unknown'),
                                 _detailRow("${l10n.timeLabel}:", timeStr),
                                 const Padding(
                                   padding: EdgeInsets.symmetric(vertical: 12),
                                   child: Divider(),
                                 ),
                                const Text("Location:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                                const SizedBox(height: 6),
                                
                                if (data['latitude'] != null && data['longitude'] != null)
                                  InkWell(
                                    onTap: () async {
                                       final urlStr = "https://www.google.com/maps?q=${data['latitude']},${data['longitude']}";
                                       final Uri url = Uri.parse(urlStr);
                                       if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open maps")));
                                       }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.map, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "https://www.google.com/maps?q=${data['latitude']},${data['longitude']}",
                                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                                      child: Text("Unable to fetch location details", style: const TextStyle(color: Colors.red)),
                                  )
                             ],
                           ),
                          ),
                        ),

                        // Actions
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                 // ACCEPT
                                 final staffUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                                 await widget.sosService.updateSOSStatus(widget.sosDoc.id, 'ACCEPTED', staffUser?.id ?? 'staff');
                                 // Immediate sound stop
                                 SoundService.stopLoop();
                                 // Overlay closes automatically via stream
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, 
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              child: const Text("ACKNOWLEDGE & RESPOND", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        )
                     ],
                   ),
             ),
           ),
        );
      }
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
        ],
      ),
    );
  }
}
