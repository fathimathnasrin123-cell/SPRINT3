import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../appointments/screens/live_queue_screen.dart';
import '../../appointments/screens/appointment_booking_screen.dart';
import '../../appointments/screens/staff_appointments_screen.dart';
import 'package:provider/provider.dart';
import '../../auth/services/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../settings/screens/settings_screen.dart';
import 'package:carenow/l10n/app_localizations.dart';
import '../../appointments/data/doctor_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../appointments/models/appointment_model.dart';
import '../../appointments/services/appointment_service.dart';
import '../../notifications/screens/notification_list_screen.dart';
import '../../sos/services/sos_service.dart'; 
import '../../../core/services/sound_service.dart';
import '../../../core/services/notification_service.dart';
import 'package:carenow/src/core/services/notification_service.dart';
import '../../appointments/widgets/rejection_dialog.dart'; // Import RejectionDialog
import 'package:url_launcher/url_launcher.dart';
import '../../services/screens/services_screen.dart'; // Import ServicesScreen
import '../../services/screens/staff_services_screen.dart'; // Import StaffServicesScreen
import '../../services/screens/volunteer_portal/volunteer_task_dashboard.dart'; 
import '../../medication/widgets/shared_medical_documents_widget.dart';
import '../../services/screens/caregiver_portal/caregiver_service_dashboard.dart';
import '../../medication/screens/medication_dashboard_screen.dart';
import 'patient_detail_screen.dart';

class DashboardScreenWrapper extends StatelessWidget {
  const DashboardScreenWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    // Check role, return appropriate scaffold
    // Use select to avoid rebuilding the entire dashboard if other AuthProvider properties change
    final userRole = context.select((AuthProvider p) => p.currentUser?.role);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    if (user == null || userRole == null) {
      return const Scaffold(body: Center(child: Text("Not Authorized")));
    }

    switch (userRole) {
      case UserRole.elderly:
        return const ElderlyDashboard();
      case UserRole.caregiver:
        return const CaregiverDashboard(); // Keep original wrapper, but modify it
      case UserRole.hospitalStaff:
        return const StaffDashboard();
      case UserRole.volunteer:
        return const VolunteerDashboard(); // Keep original wrapper, but modify it
      default:
        return const Scaffold(body: Center(child: Text("Unknown Role")));
    }
  }
}

class NotificationBadgeButton extends StatelessWidget {
  final String userId;
  const NotificationBadgeButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final isStaff = user?.role.name == 'hospitalStaff';
    final targetIds = isStaff ? [userId, 'staff_broadcast'] : [userId];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', whereIn: targetIds)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_active),
              tooltip: "Notifications",
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationListScreen()));
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      }
    );
  }
}

// --------------------- ELDERLY DASHBOARD ---------------------
class ElderlyDashboard extends StatefulWidget {
  const ElderlyDashboard({super.key});

  @override
  State<ElderlyDashboard> createState() => _ElderlyDashboardState();
}

class _ElderlyDashboardState extends State<ElderlyDashboard> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _sosStream;
  String? _userId;
  StreamSubscription? _notificationSub;
  bool _isFirstNotificationLoad = true;

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  void _setupNotificationListener(String uid) {
    if (_notificationSub != null) return;
    _notificationSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (_isFirstNotificationLoad) {
        _isFirstNotificationLoad = false;
        return;
      }
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null && data['type'] == 'service_update') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? 'Update', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(data['message'] ?? ''),
                    ],
                  ),
                  backgroundColor: Colors.teal.shade700,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: "View",
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationListScreen()));
                    },
                  ),
                ),
              );
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    
    if (user != null && _userId != user.id) {
      _userId = user.id;
      _sosStream = SOSService().getUserSOSStream(user.id);
      _setupNotificationListener(user.id);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myCare),
        actions: [
          if (_userId != null) NotificationBadgeButton(userId: _userId!),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          )
        ],
      ),
      body: Listener(
        onPointerDown: (_) {
           // UNLOCK AUDIO ON ANY INTERACTION
           SoundService.initializeAudio();
        },
        child: Column(
          children: [
            _SOSStatusBox(sosStream: _sosStream),
            const _LiveQueueAlertCard(),
            const _AppointmentStatusBox(),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _BigCard(
                     icon: Icons.medication, 
                     label: l10n.medication, 
                     color: Colors.blueAccent,
                     onTap: () {
                        final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                        if (user != null) {
                           Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => MedicationDashboardScreen(patientId: user.id))
                           );
                        }
                     },
                  ),
                  _BigCard(
                     icon: Icons.calendar_month, 
                     label: l10n.appointments, 
                     color: Colors.green,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentBookingScreen())),
                  ),
                  // Wrap Emergency Button in StreamBuilder to Check Active Status
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _sosStream,
                    builder: (context, snapshot) {
                       bool isSOSActive = false;
                       if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                          final sos = snapshot.data!.docs.first.data();
                          final status = (sos['status'] as String).toUpperCase();
                          if (status == 'PENDING') {
                             isSOSActive = true;
                          } else {
                             Timestamp? response = sos['responseTimestamp'];
                             if (response != null) {
                                // Persist for 60 minutes
                                if (DateTime.now().difference(response.toDate()).inMinutes.abs() < 60) {
                                    isSOSActive = true;
                                }
                             } else {
                                // If response is null but status implies active, keep active
                                isSOSActive = true;
                             }
                          }
                       }
  
                       return _BigCard(
                         icon: Icons.call, 
                         label: l10n.emergency, 
                         color: isSOSActive ? Colors.grey : Colors.red,
                         onTap: () {
                            if (isSOSActive) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text("Emergency Request Active. Please wait."))
                               );
                            } else {
                               _showEmergencyConfirmation(context, l10n);
                            }
                         },
                       );
                    }
                  ),
                  _BigCard(
                     icon: Icons.person, 
                     label: l10n.myDetails, 
                     color: Colors.orange,
                     onTap: () {
                        final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                        if (user != null) {
                            final userData = user.toMap();
                            userData['uid'] = user.id; // required by PatientDetailScreen map
                            userData['id'] = user.id;
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailScreen(patientData: userData)));
                        }
                     },
                  ),
                  _BigCard(
                     icon: Icons.queue_play_next, 
                     label: l10n.liveQueue, 
                     color: Colors.purple,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveQueueScreen(isStaff: false))),
                  ),
                  _BigCard(
                     icon: Icons.handshake, 
                     label: "Services", 
                     color: Colors.indigoAccent,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showEmergencyConfirmation(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(children: [const Icon(Icons.warning, color: Colors.red), const SizedBox(width: 8), Text(l10n.emergencyConfirmation)]), 
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.confirmEmergency),
            const SizedBox(height: 12),
            Text(
              l10n.emergencyDisclaimer,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
               Navigator.pop(context);
               final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
               if (user != null) {
                  SOSService().triggerSOS(role: 'elderly');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.emergencyAlertSent), backgroundColor: Colors.red)
                  );
                  // Success feedback handled
               }
            },
            child: Text(l10n.confirm),
          )
        ],
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _BigCard({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.2))),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

}

class _HospitalAccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final l10n = AppLocalizations.of(context)!;
    String label = l10n.requestHospitalAccess;
    Color color = Colors.purple;
    VoidCallback? onTap = () {
      Provider.of<AuthProvider>(context, listen: false).requestHospitalAccess();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.accessRequested)));
    };

    if (user?.hospitalAccessStatus == 'pending') {
      label = l10n.accessPending;
      color = Colors.orange;
      onTap = null;
    } else if (user?.hospitalAccessStatus == 'approved') {
      label = l10n.accessApproved;
      color = Colors.green;
      onTap = null;
    }

    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.2))),
      child: InkWell(
        onTap: () {
            // Navigate "inside" to request appointment/access
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalAccessScreen()));
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital, size: 48, color: color),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class HospitalAccessScreen extends StatelessWidget {
  const HospitalAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = Provider.of<AuthProvider>(context).currentUser;
    final status = user?.hospitalAccessStatus;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hospitalAccess)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status == 'pending') ...[
               const Icon(Icons.access_time, size: 80, color: Colors.orange),
               const SizedBox(height: 16),
               Text(l10n.accessPending, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ] else if (status == 'approved') ...[
               const Icon(Icons.check_circle, size: 80, color: Colors.green),
               const SizedBox(height: 16),
               Text(l10n.accessApproved, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 20),
               ElevatedButton(
                 onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentBookingScreen())), 
                 child: Text(l10n.appointments)
               )
            ] else ...[
               const Icon(Icons.local_hospital, size: 80, color: Colors.blue),
               const SizedBox(height: 16),
               Text(l10n.requestHospitalAccess, style: const TextStyle(fontSize: 20)),
               const SizedBox(height: 20),
               ElevatedButton(
                 onPressed: () {
                   Provider.of<AuthProvider>(context, listen: false).requestHospitalAccess();
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.accessRequested)));
                 },
                 child: Text(l10n.sendRequest),
               ),
            ]
          ],
        ),
      ),
    );
  }
}

// --------------------- CAREGIVER DASHBOARD ---------------------
class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  @override
  void initState() {
    super.initState();
    // Initial fetch if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final provider = Provider.of<AuthProvider>(context, listen: false);
       if (provider.linkedProfiles.isEmpty) {
          provider.fetchLinkedElderlyProfiles();
       }
    });
  }

  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch(e) {
      debugPrint('Launch ERROR $e');
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildVitalStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
           final linkedElderly = authProvider.linkedProfiles;
  
            return Scaffold(
                   appBar: AppBar(
                     title: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('linked_users').doc(authProvider.currentUser?.id).collection('elderlies').snapshots(),
                        builder: (context, snapshot) {
                           final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                           return Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(l10n.caregiverFamily),
                               Text("Linked Elderlies: $count/5", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                             ],
                           );
                        }
                     ),
                     actions: [
                       NotificationBadgeButton(userId: authProvider.currentUser?.id ?? ''),
                       IconButton(
                         icon: const Icon(Icons.settings),
                         onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                       )
                     ],
                     bottom: const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.medical_services), text: "Health Monitor"),
                        Tab(icon: Icon(Icons.assignment), text: "Service Requests"),
                      ],
                    ),
                  ),
                  body: TabBarView(
                    children: [
                      // TAB 1: HEALTH MONITOR
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('linked_users').doc(authProvider.currentUser?.id).collection('elderlies').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.link_off, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text("No elderly linked yet.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                                ],
                              ),
                            );
                          }

                          final linkedDocs = snapshot.data!.docs;
                          
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: linkedDocs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                               final doc = linkedDocs[index];
                               final elderlyId = doc['elderlyId'];

                               return StreamBuilder<DocumentSnapshot>(
                                 stream: FirebaseFirestore.instance.collection('users').doc(elderlyId).snapshots(),
                                 builder: (context, userSnap) {
                                   if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                                   
                                   final data = userSnap.data!.data() as Map<String, dynamic>;
                                   final name = data['name'] ?? 'Unknown';
                                   final age = data['age']?.toString() ?? 'N/A';
                                   final bloodPressure = data['bloodPressure'] ?? 'N/A';
                                   final sugarLevel = data['sugarLevel'] ?? 'N/A';
                                   final conditions = data['conditions']?.isNotEmpty == true ? data['conditions'] : 'None reported';
                                   final medicines = data['medicines']?.isNotEmpty == true ? data['medicines'] : 'None reported';
                                   final storedVitals = data['storedVitals'] ?? data['vitals'] ?? 'No extra vitals stored';
                                   
                                   // Keep SOS Monitor
                                   return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                     stream: SOSService().getUserSOSStream(elderlyId),
                                     builder: (context, sosSnapshot) {
                                       bool isEmergency = false;
                                       if (sosSnapshot.hasData && sosSnapshot.data!.docs.isNotEmpty) {
                                          if (sosSnapshot.data!.docs.first.data()['status'] == 'PENDING') {
                                             isEmergency = true;
                                          }
                                       }
           
                                       return Card(
                                         elevation: isEmergency ? 8 : 4,
                                         margin: const EdgeInsets.only(bottom: 24),
                                         color: isEmergency ? Colors.red.shade50 : Colors.white,
                                         shape: RoundedRectangleBorder(
                                           borderRadius: BorderRadius.circular(16),
                                           side: isEmergency ? const BorderSide(color: Colors.red, width: 2) : BorderSide(color: Colors.grey.shade300)
                                         ),
                                         child: Padding(
                                           padding: const EdgeInsets.all(16.0),
                                           child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                                // 1. HEADER SECTION
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name.toUpperCase(),
                                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo, letterSpacing: 1.1),
                                                      ),
                                                    ),
                                                    if (!isEmergency) 
                                                      ElevatedButton.icon(
                                                        onPressed: () {
                                                          data['id'] = elderlyId;
                                                          final userObj = User.fromMap(data);
                                                          _showCaregiverEmergencyConfirmation(context, userObj);
                                                        },
                                                        icon: const Icon(Icons.warning, size: 16),
                                                        label: const Text("SOS"),
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                                      ),
                                                    if (isEmergency)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 8)]),
                                                        child: Row(
                                                          children: [
                                                            const Icon(Icons.warning, color: Colors.white, size: 16),
                                                            const SizedBox(width: 4),
                                                            Text(l10n.emergency.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                          ],
                                                        ),
                                                      )
                                                  ],
                                                ),
                                                const Divider(height: 24, thickness: 1),

                                                // 2. PERSONAL INFORMATION SECTION
                                                _buildSectionHeader("Personal Details", Icons.person, Colors.blue),
                                                const SizedBox(height: 12),
                                                _buildDetailRow("Full Name", name),
                                                _buildDetailRow("DOB", data['dob'] ?? 'N/A'),
                                                _buildDetailRow("Age", age),
                                                _buildDetailRow("Gender", data['gender'] ?? 'N/A'),
                                                _buildDetailRow("Address", data['address'] ?? 'N/A'),
                                                _buildDetailRow("Contact", data['contactNumber'] ?? 'N/A'),
                                                _buildDetailRow("Emergency", data['emergencyContact'] ?? 'N/A'),
                                                
                                                const SizedBox(height: 16),

                                                // 3. HEALTH METRICS SECTION
                                                _buildSectionHeader("Health Metrics", Icons.favorite, Colors.red),
                                                const SizedBox(height: 12),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    _buildVitalStat("Blood Pressure", bloodPressure),
                                                    _buildVitalStat("Sugar Level", sugarLevel),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                const Text("Stored Vitals", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
                                                Text(storedVitals, style: const TextStyle(fontSize: 13)),
                                                const SizedBox(height: 12),
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text("Medical Conditions", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                                                          const SizedBox(height: 4),
                                                          Text(conditions, style: const TextStyle(fontSize: 13)),
                                                        ],
                                                      )
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text("Medications", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                                                          const SizedBox(height: 4),
                                                          Text(medicines, style: const TextStyle(fontSize: 13)),
                                                        ],
                                                      )
                                                    ),
                                                  ]
                                                ),
                                                
                                                const SizedBox(height: 16),

                                                // 4. MEDICAL DOCUMENTS SECTION
                                                SharedMedicalDocumentsWidget(elderlyId: elderlyId),

                                                const SizedBox(height: 16),

                                                // 5. VOLUNTEER SERVICES SECTION
                                                _buildSectionHeader("Volunteer Services", Icons.volunteer_activism, Colors.orange),
                                                const SizedBox(height: 8),
                                                StreamBuilder<QuerySnapshot>(
                                                  stream: FirebaseFirestore.instance.collection('volunteer_requests').where('userId', isEqualTo: elderlyId).snapshots(),
                                                  builder: (context, volSnap) {
                                                    if (!volSnap.hasData) return const Text("Loading requests...", style: TextStyle(color: Colors.grey, fontSize: 12));
                                                    if (volSnap.data!.docs.isEmpty) return const Text("No volunteer requests.", style: TextStyle(color: Colors.grey, fontSize: 12));
                                                    
                                                    return ListView.builder(
                                                      shrinkWrap: true,
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      itemCount: volSnap.data!.docs.length,
                                                      itemBuilder: (context, index) {
                                                         final volData = volSnap.data!.docs[index].data() as Map<String, dynamic>;
                                                         final type = volData['serviceType'] ?? 'Service';
                                                         final status = volData['status'] ?? 'Pending';
                                                         
                                                         Color stColor = Colors.orange;
                                                         if (status == 'Approved' || status == 'Accepted') stColor = Colors.green;
                                                         if (status == 'Completed') stColor = Colors.blue;
                                                         if (status == 'Rejected') stColor = Colors.red;

                                                         return Container(
                                                           margin: const EdgeInsets.only(bottom: 6),
                                                           padding: const EdgeInsets.all(8),
                                                           decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                                           child: Row(
                                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                             children: [
                                                               Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                               Container(
                                                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                 decoration: BoxDecoration(color: stColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                                                 child: Text(status, style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                                               )
                                                             ],
                                                           )
                                                         );
                                                      },
                                                    );
                                                  }
                                                ),
                                             ],
                                           ),
                                         ),
                                       );
                                     }
                                   );
                                 }
                               );
                            },
                          );
                        }
                      ),
                      
                      // TAB 2: SERVICE REQUESTS (EMBEDDED)
                      const CaregiverServiceDashboard(), 
                    ],
                  ),
               );
        },
      ),
    );
  }
  void _showCaregiverEmergencyConfirmation(BuildContext context, User patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text("Emergency for Patient")]), 
        content: Text("Are you sure you want to raise an emergency alert for ${patient.name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
               Navigator.pop(context);
               SOSService().triggerSOS(role: 'caregiver', overrideUserId: patient.id);
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text("Emergency Alert Sent for ${patient.name}!"), backgroundColor: Colors.red)
               );
            },
            child: const Text("Confirm"),
          )
        ],
      ),
    );
  }
}

// --------------------- STAFF DASHBOARD ---------------------
class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  // List<Map<String, String>> _allPatients = [ ... ]; // Removed Mock Data
  List<Map<String, String>> _filteredPatients = [];

  @override
  // Timer? _soundTimer; // Moved
  // StreamSubscription? _emergencySub; // Moved

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Initial fetch if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final provider = Provider.of<AuthProvider>(context, listen: false);
       if (provider.linkedProfiles.isEmpty) {
          provider.fetchLinkedElderlyProfiles();
       }
    });
    // Sound logic moved to GlobalSystemManager
  }

  void _onSearchChanged() {
    setState(() {}); // Trigger rebuild to filter stream
  }


  @override
  void dispose() {
    _searchController.dispose();
    // _emergencySub?.cancel();
    // _stopEmergencySound();
    super.dispose();
  }

  // void _startEmergencySound() { ... } // Removed
  // void _stopEmergencySound() { ... } // Removed

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text(l10n.staffPortal),
             actions: [
                NotificationBadgeButton(userId: Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? ''),
                IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.large(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffAppointmentsScreen()));
            },
            child: const Icon(Icons.calendar_today),
          ),
          body: Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchByUniqueId,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              // Patient List
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Provider.of<AuthProvider>(context, listen: false).getPatientsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    
                    final allPatients = snapshot.data ?? [];
                    
                    // Filter
                    final query = _searchController.text.trim();
                    final patients = query.isEmpty 
                        ? allPatients 
                        : allPatients.where((p) => (p['uniqueId'] ?? '').toString().contains(query)).toList();

                    if (patients.isEmpty) {
                       return Center(child: Text(l10n.profileNotFound, style: const TextStyle(fontSize: 18, color: Colors.grey)));
                    }

                    return ListView.builder(
                        itemCount: patients.length,
                        itemBuilder: (context, index) {
                          final p = patients[index];
                          final isPending = p['hospitalAccessStatus'] == 'pending';
                          final isApproved = p['hospitalAccessStatus'] == 'approved';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(child: Text((p['name'] ?? 'U')[0])),
                              title: Text(p['name'] ?? l10n.unknown, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(p['uniqueId'] ?? l10n.noId),
                              trailing: isPending 
                                  ? Chip(label: Text(l10n.request), backgroundColor: Colors.orangeAccent)
                                  : (isApproved ? const Icon(Icons.check_circle, color: Colors.green) : null),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailScreen(patientData: p.cast<String, dynamic>())));
                              },
                            ),
                          );
                        },
                      );
                  },
                ),
              ),
            ],
          ),
        ),
        
        // --- EMERGENCY OVERLAY (PERSISTENT & BLOCKING) ---
        // --- EMERGENCY OVERLAY REMOVED (Handled by GlobalSystemManager) ---

      ],
    );
  }
}

class _EmergencyInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _EmergencyInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 12)),
           Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// --------------------- VOLUNTEER DASHBOARD ---------------------
class VolunteerDashboard extends StatelessWidget {
  const VolunteerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.volunteerHub),
        actions: [
          NotificationBadgeButton(userId: Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? ''),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volunteer_activism, size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 24),
            Text(
              l10n.welcomeVolunteer,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(l10n.thankYouVolunteer),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VolunteerTaskDashboard()),
                );
              },
              child: Text(l10n.viewAvailableTasks),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentStatusBox extends StatefulWidget {
  const _AppointmentStatusBox();

  @override
  State<_AppointmentStatusBox> createState() => _AppointmentStatusBoxState();
}

class _AppointmentStatusBoxState extends State<_AppointmentStatusBox> {
  Stream<QuerySnapshot>? _appointmentsStream;
  String? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user != null && user.id != _lastUserId) {
      _lastUserId = user.id;
      _appointmentsStream = FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: user.id)
          .where('status', whereIn: ['pending', 'approved', 'serving', 'waiting', 'rejected', 'completed'])
          .limit(10)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    
    if (_appointmentsStream == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _appointmentsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        
        // Flicker-free loading: Show spinner only if no data yet
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
           return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }

        final docs = snapshot.data?.docs ?? [];
        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

        final validDocs = docs.where((doc) {
           final data = doc.data() as Map<String, dynamic>;
           final aptDate = (data['appointmentDate'] as Timestamp).toDate();
           final aptDay = DateTime(aptDate.year, aptDate.month, aptDate.day);
           return !aptDay.isBefore(today);
        }).toList();

        validDocs.sort((a, b) {
           final sA = (a.data() as Map)['status'];
           final sB = (b.data() as Map)['status'];
           if (sA == 'approved' || sA == 'serving') return -1;
           if (sB == 'approved' || sB == 'serving') return 1;
           if (sA == 'pending') return -1;
           if (sB == 'pending') return 1;
           return 0;
        });

        // CASE 1: No Appointment Taken (Empty or Expired)
        if (validDocs.isEmpty) {
           return Container(
             margin: const EdgeInsets.all(16),
             padding: const EdgeInsets.all(20),
             width: double.infinity,
             decoration: BoxDecoration(
               color: Colors.grey.shade200,
               borderRadius: BorderRadius.circular(16),
             ),
             child: Column(
               children: [
                 const Icon(Icons.calendar_today, color: Colors.grey, size: 40),
                 const SizedBox(height: 10),
                 Text(
                   "0 ${l10n.appointments}", 
                   style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                 ),
                 Text(l10n.noAppointmentTaken, style: const TextStyle(color: Colors.grey)), 
               ],
             ),
           );
        }

        // Active Appointment Exists
        final docVal = validDocs.first;
        final data = docVal.data() as Map<String, dynamic>;
        final status = data['status'];
        final doctorEn = data['doctorName'] ?? 'Unknown';
        final deptEn = data['department'] ?? 'General';
        final date = (data['appointmentDate'] as Timestamp).toDate();
        final dateStr = DateFormat('EEEE, MMM d, yyyy', locale).format(date); // Localized Date
        final token = data['tokenNumber']?.toString() ?? '0';
        
        final doctorName = DoctorData.getDoctorName(doctorEn, locale);
        final department = DoctorData.getDoctorDepartment(deptEn, locale);

        // Define Styling based on Status
        Color bgColor;
        Color borderColor;
        Color textColor;
        String statusText;
        IconData icon;
        bool showToken = false;

        if (status == 'pending') {
           bgColor = Colors.orange.shade50;
           borderColor = Colors.orange.shade200;
           textColor = Colors.orange.shade800;
           statusText = l10n.requestSentPending;
           icon = Icons.hourglass_top;
        } else if (status == 'rejected') {
           bgColor = Colors.red.shade50;
           borderColor = Colors.red.shade200;
           textColor = Colors.red.shade800;
           statusText = l10n.appointmentRejected;
           icon = Icons.cancel;
        } else if (status == 'approved' || status == 'serving' || status == 'waiting') {
           bgColor = Colors.green.shade50;
           borderColor = Colors.green.shade200;
           textColor = Colors.green.shade800;
           statusText = l10n.approved; // Or specific status like serving
           icon = Icons.check_circle;
           showToken = true;
        } else {
           bgColor = Colors.grey.shade100;
           borderColor = Colors.grey.shade300;
           textColor = Colors.grey.shade700;
           statusText = _getStatusLoc(status, l10n);
           icon = Icons.info;
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Icon(icon, color: textColor, size: 28),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           statusText, 
                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
                         ),
                         const SizedBox(height: 8),
                         if (showToken) ...[
                            Text(
                              "${l10n.yourToken}: $token",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)
                            ),
                            const SizedBox(height: 8),
                         ],
                         Text(doctorName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                         Text(department, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                         const SizedBox(height: 4),
                         Text("${l10n.date}: $dateStr", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                         if (status == 'rejected') ...[
                             const SizedBox(height: 12),
                             Container(
                               padding: const EdgeInsets.all(10),
                               width: double.infinity,
                               decoration: BoxDecoration(
                                 color: Colors.white.withOpacity(0.7),
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: Colors.red.shade100),
                               ),
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     l10n.reasonLabel, 
                                     style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 13)
                                   ),
                                   const SizedBox(height: 4),
                                   Text(
                                     _getRejectionReasonText(data['rejectionReason'] as String?, l10n), // Use Helper
                                     style: TextStyle(color: Colors.red.shade900, fontSize: 15, fontWeight: FontWeight.w500),
                                   ),
                                    const SizedBox(height: 6),
                                    Text(l10n.pleaseReschedule, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.red.shade700))
                                 ],
                               ),
                             ),
                         ],
                       ],
                     ),
                   ),
                 ],
               ),
            ],
          ),
        );
      },
    );
  }
  String _getStatusLoc(String? status, AppLocalizations l10n) {
    if (status == 'pending') return l10n.pending;
    if (status == 'approved') return l10n.approved;
    if (status == 'rejected') return l10n.rejected;
    if (status == 'serving') return l10n.nowServing;
    if (status == 'completed') return l10n.complete;
    return status ?? l10n.unknown;
  }

  String _getRejectionReasonText(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return "";
    switch (value) {
      case 'reasonDoctorUnavailable': return l10n.reasonDoctorUnavailable;
      case 'reasonSlotFull': return l10n.reasonSlotFull;
      case 'reasonIncompleteDetails': return l10n.reasonIncompleteDetails;
      case 'reasonReschedule': return l10n.reasonReschedule;
      case 'reasonEmergencyPriority': return l10n.reasonEmergencyPriority;
      case 'reasonOther': return l10n.reasonOther;
      default: return value; // Return custom text as is (or translate if needed? custom is usually custom)
    }
  }
}

class _StaffRightPanel extends StatelessWidget {
  const _StaffRightPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        // 1. Live Queue Section
        Expanded(
          flex: 6, // 60% height
          child: Column(
            children: [
               Container(
                 padding: const EdgeInsets.all(12),
                 color: Colors.teal.shade700,
                 width: double.infinity,
                 child: Row(
                   children: [
                     const Icon(Icons.queue, color: Colors.white),
                     const SizedBox(width: 8),
                     Text(l10n.liveQueue, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                   ],
                 ),
               ),
               Expanded(child: _LiveQueueSection()),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 2),
        // 2. Requests Section
        Expanded(
          flex: 4, // 40% height
          child: Column(
            children: [
               Container(
                 padding: const EdgeInsets.all(12),
                 color: Colors.orange.shade700,
                 width: double.infinity,
                 child: Row(
                   children: [
                     const Icon(Icons.notification_important, color: Colors.white),
                     const SizedBox(width: 8),
                     Text(l10n.appointmentRequests, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                   ],
                 ),
               ),
               Expanded(child: _RequestsSection()),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveQueueSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appointmentService = AppointmentService();
    // Assuming we are viewing today's queue
    final today = DateTime.now();
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    return StreamBuilder<List<AppointmentModel>>(
      stream: appointmentService.getLiveQueue(today),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final allAppointments = snapshot.data ?? [];
        if (allAppointments.isEmpty) {
           return Center(child: Text(l10n.noActiveQueue));
        }

        // Logic (Same as LiveQueueScreen but condensed)
        final serving = allAppointments.where((a) => a.status == AppointmentStatus.serving).toList();
        AppointmentModel? current = serving.isNotEmpty ? serving.first : null;
        
        if (current == null) {
           final pending = allAppointments.where((a) => a.status == AppointmentStatus.pending).toList();
           if (pending.isNotEmpty) current = pending.first;
        }

        final upcoming = current != null 
            ? allAppointments.where((a) => a.status == AppointmentStatus.pending && a.id != current!.id).toList()
            : [];

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (current != null) ...[
               Text(l10n.nowServing, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey)),
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(12),
                   boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                   border: Border.all(color: Colors.teal.shade200, width: 2),
                 ),
                 child: Column(
                   children: [
                     Text("#${current.tokenNumber}", style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal)),
                     Text(DoctorData.getDoctorName(current.doctorName, locale), style: const TextStyle(fontWeight: FontWeight.bold)),
                     Text(DoctorData.getDoctorDepartment(current.department, locale)),
                     const Divider(),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                       children: [
                        if (current.status == AppointmentStatus.serving)
                          ElevatedButton.icon(
                            onPressed: () => appointmentService.updateStatus(current!.id, AppointmentStatus.completed),
                            icon: const Icon(Icons.check),
                            label: Text(l10n.complete),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => appointmentService.updateStatus(current!.id, AppointmentStatus.serving),
                            icon: const Icon(Icons.notifications_active),
                            label: Text(l10n.callToken),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                          )
                       ],
                     )
                   ],
                 ),
               ),
            ],
            const SizedBox(height: 16),
            Text(l10n.upNext, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ...upcoming.map((apt) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  child: Text("${apt.tokenNumber}"),
                ),
                title: Text(DoctorData.getDoctorName(apt.doctorName, locale)),
                subtitle: Text(DoctorData.getDoctorDepartment(apt.department, locale)),
                trailing: const Icon(Icons.access_time, size: 16),
              ),
            )),
          ],
        );
      },
    );
  }
}

class _RequestsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appointmentService = AppointmentService();
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final user = Provider.of<AuthProvider>(context).currentUser;

    return StreamBuilder<List<AppointmentModel>>(
      stream: appointmentService.getPendingAppointments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
           return Center(child: Text(l10n.noPendingAppointments));
        }
        
        final appointments = snapshot.data!;
        
        return ListView.separated(
          itemCount: appointments.length,
          padding: const EdgeInsets.all(12),
          separatorBuilder: (_,__) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
             final apt = appointments[index];
             final doctorName = DoctorData.getDoctorName(apt.doctorName, locale);

             return Card(
               elevation: 2,
               child: Padding(
                 padding: const EdgeInsets.all(12.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Show Patient Name as requested
                     Text(apt.patientName ?? apt.patientId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     Text("$doctorName - ${DoctorData.getDoctorDepartment(apt.department, locale)}"),
                     Text(DateFormat('MMM dd').format(apt.appointmentDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                     const SizedBox(height: 8),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         TextButton(
                           onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => RejectionDialog(
                                  onConfirm: (reason) {
                                    appointmentService.updateStatus(apt.id, AppointmentStatus.rejected, staffId: user?.id, rejectionReason: reason);
                                  }
                                )
                              );
                           },
                           child: Text(l10n.reject, style: const TextStyle(color: Colors.red)),
                         ),
                         const SizedBox(width: 8),
                         ElevatedButton(
                           onPressed: () => appointmentService.updateStatus(apt.id, AppointmentStatus.approved, staffId: user?.id),
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                           child: Text(l10n.approve),
                         ),
                       ],
                     )
                   ],
                 ),
               ),
             );
          },
        );
      },
    );
  }
}

class _SOSStatusBox extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? sosStream;
  const _SOSStatusBox({super.key, this.sosStream});

  @override
  State<_SOSStatusBox> createState() => _SOSStatusBoxState();
}

class _SOSStatusBoxState extends State<_SOSStatusBox> {
  Timer? _soundTimer;
  final Set<String> _handledStatuses = {};
  bool _isSilenced = false;

  @override
  void dispose() {
    _soundTimer?.cancel();
    SoundService.stopLoop();
    super.dispose();
  }

  void _triggerSound(String statusKey) {
     if (_handledStatuses.contains(statusKey)) return;
     if (_isSilenced) return;
     _handledStatuses.add(statusKey);
     
     WidgetsBinding.instance.addPostFrameCallback((_) {
        // Play exactly 3 times for Elderly
        SoundService.playSOSXTimes(3);
     });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sosStream == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.sosStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
           if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
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

        final sos = docs.first.data();
        final status = (sos['status'] as String).toUpperCase();
        final timestamp = sos['timestamp'] as Timestamp?;
        final responseTime = sos['responseTimestamp'] as Timestamp?;
        
        // 1. PENDING
        if (status == 'PENDING' || status == 'REQUESTED') {
           // No Sound for Pending for Elderly as requested
           return _buildBox(
             color: Colors.red,
             header: l10n.emergency,
             msg: l10n.sosSentWaiting,
             icon: Icons.hourglass_empty,
             isProgress: true,
             l10n: l10n,
             diffInMinutes: 0,
           );
        }

        // 2. ACCEPTED / APPROVED / RESOLVED (Stable for 1 Hour)
        final effectiveTime = responseTime?.toDate() ?? DateTime.now();
        final diff = DateTime.now().difference(effectiveTime).abs();

        if (diff.inMinutes < 60) {
            Color color = Colors.green;
            String header = l10n.approved; 
            String msg = l10n.helpOnTheWay;
            IconData icon = Icons.support_agent;
            bool isApproved = false;

            if (status == 'RESOLVED') {
                msg = l10n.emergencyResolved;
                icon = Icons.check_circle;
                color = Colors.blue;
                header = l10n.emergencyResolved;
            } else if (status == 'REJECTED') {
                msg = l10n.emergencyClosed;
                color = Colors.grey;
                icon = Icons.cancel;
                header = l10n.emergencyClosed;
            } else if (status == 'ACCEPTED' || status == 'APPROVED') {
                isApproved = true;
            }

            if (isApproved && diff.inSeconds < 60) _triggerSound('APPROVED');

            return _buildBox(
              color: color,
              header: header,
              msg: msg,
              icon: icon,
              l10n: l10n,
              diffInMinutes: diff.inMinutes,
            );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => SoundService.stopLoop());
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBox({
    required Color color,
    required String header,
    required String msg,
    required IconData icon,
    bool isProgress = false,
    required AppLocalizations l10n,
    required int diffInMinutes,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (isProgress)
             SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: color))
          else
             Icon(icon, size: 32, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(header, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
                Text(msg, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                if (!isProgress)
                  Text(
                    l10n.msgClearTimer((60 - diffInMinutes).toString()),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}





class _LiveQueueAlertCard extends StatefulWidget {
  const _LiveQueueAlertCard();

  @override
  State<_LiveQueueAlertCard> createState() => _LiveQueueAlertCardState();
}

class _LiveQueueAlertCardState extends State<_LiveQueueAlertCard> {
  // We need to listen to the specific doctor's queue if the user has an active token.
  @override
  void dispose() {
    NotificationService().stopQueueMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;

    if (user == null) return const SizedBox.shrink();

    // 1. Get Active Appointment with Token
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: user.id)
          .where('status', whereIn: ['approved', 'serving', 'waiting']) // Only active states
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

        // Filter for Today & Valid Token
        final validDocs = docs.where((doc) {
           final data = doc.data() as Map<String, dynamic>;
           final aptDate = (data['appointmentDate'] as Timestamp).toDate();
           final aptDay = DateTime(aptDate.year, aptDate.month, aptDate.day);
           final token = data['tokenNumber'];
           return !aptDay.isBefore(today) && token != null && (token is int) && token > 0;
        }).toList();

        if (validDocs.isEmpty) return const SizedBox.shrink();

        // Sort by Token (User might have multiple, assume first one is priority)
        validDocs.sort((a, b) {
            final tA = (a.data() as Map)['tokenNumber'] as int;
            final tB = (b.data() as Map)['tokenNumber'] as int;
            return tA.compareTo(tB);
        });

        final myApt = validDocs.first.data() as Map<String, dynamic>;
        final String appointmentId = validDocs.first.id; 
        final myToken = myApt['tokenNumber'] as int;
        final doctorEn = myApt['doctorName'] as String;
        final int? aptThreshold = myApt['alarmTokenDistance']; // Get saved preference
        final bool hasTriggered = myApt['alertTriggered'] ?? false; // Check persistence
        final bool isUpNextPersistent = myApt['isUpNext'] ?? false; // Explicit State

        // 2. Listen to Live Queue for this Doctor
        final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
        final docKey = doctorEn.replaceAll(RegExp(r'\s+'), '_');
        final queueDocId = "${dateString}_$docKey";
        
        // Start monitoring: Service handles sound and Firestore updates
        NotificationService().startQueueMonitoring(
             queueDocId, 
             myToken, 
             alarmDistance: aptThreshold,
             appointmentId: appointmentId,
             alreadyTriggered: hasTriggered
        );

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('live_queue').doc(queueDocId).snapshots(),
          builder: (context, queueSnap) {
            if (!queueSnap.hasData || !queueSnap.data!.exists) return const SizedBox.shrink();

            final qData = queueSnap.data!.data() as Map<String, dynamic>;
            final currentToken = qData['currentToken'] as int? ?? 0;
            
            final diff = myToken - currentToken;
            final threshold = aptThreshold ?? NotificationService().tokenAlertThreshold;
            
            // 4. Check Condition
            // Show if Persisted State is TRUE OR Calculation is Valid
            final bool conditionMet = diff <= threshold && currentToken < myToken + 1;

            if (isUpNextPersistent || (conditionMet && diff > 0)) { 
               if (currentToken > myToken) return const SizedBox.shrink(); 

               return InkWell(
                  onTap: () {
                      // Stop sound on tap
                      SoundService.stopLoop();
                      // Optional: Navigate to Live Queue on tap? User requested just "stop sound" in text.
                      // But usually user might want to see details. Prompt says "stop only when the user taps the alert message box".
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.red),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              diff > 1 
                                  ? (locale == 'ml' ? "നിങ്ങളുടെ ഊഴം അടുത്തെത്തി! ($diff)" : "ALERT: YOU ARE $diff TOKENS AWAY!")
                                  : l10n.upNext.toUpperCase(),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                            ),
                            Text(
                              locale == 'ml' ? "ശബ്ദം നിർത്താൻ ഇവിടെ അമർത്തുക" : "Tap here to stop alert",
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.red.shade600),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                );
            }
            
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
} // End of class _LiveQueueAlertCard
