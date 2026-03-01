import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/services/auth_provider.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';
import 'package:carenow/l10n/app_localizations.dart';
import '../data/doctor_data.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:carenow/src/core/services/notification_service.dart'; 
import 'package:carenow/src/core/services/sound_service.dart'; // Added Import

class LiveQueueScreen extends StatefulWidget { // Converted to StatefulWidget
  final bool isStaff;
  final bool embed;
  const LiveQueueScreen({super.key, this.isStaff = false, this.embed = false});

  @override
  State<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends State<LiveQueueScreen> {

  @override
  void initState() {
    super.initState();
    if (!widget.isStaff) {
       // Load user prefs to ensure correct fallback thresholds
       WidgetsBinding.instance.addPostFrameCallback((_) {
          final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
          if (user != null) {
             NotificationService().loadUserPreferences(user.id);
          }
       });
    }
  }

  @override
  void dispose() {
    // Stop monitoring and ANY looping sound when leaving the screen
    if (!widget.isStaff) {
       NotificationService().stopQueueMonitoring();
       SoundService.stopLoop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentService = AppointmentService();
    final user = Provider.of<AuthProvider>(context).currentUser;
    final currentUserId = user?.id;

    final today = DateTime.now();
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final doctors = DoctorData.doctors;

    final content = LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.teal.shade50, Colors.white],
            ),
          ),
          child: StreamBuilder<List<AppointmentModel>>(
            stream: appointmentService.getLiveQueue(today),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              }

              final allAppointments = snapshot.data ?? [];

              // --- STAFF VIEW: Vertical List ---
              if (widget.isStaff) {
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: doctors.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    final docName = doctor['name_en'] ?? 'Doctor';
                    return _buildStaffQueueBox(
                      context, 
                      doctor, 
                      allAppointments.where((a) => a.doctorName == docName).toList(),
                      appointmentService, 
                      l10n,
                      locale
                    );
                  },
                );
              }
              
              // --- ELDERLY VIEW ---
              if (snapshot.hasError) {
                return Center(child: Text("Error loading queue: ${snapshot.error}"));
              }

              final myAppointments = allAppointments.where(
                 (a) => a.patientId == currentUserId
              ).toList();
              
              final activeAppointments = myAppointments.where((a) => 
                  a.status != AppointmentStatus.cancelled && 
                  a.status != AppointmentStatus.rejected
              ).toList();

              final todayDay = DateTime(today.year, today.month, today.day);
              if (activeAppointments.isEmpty) {
                 final rejectedToday = myAppointments.where((a) {
                    final aptDay = DateTime(a.appointmentDate.year, a.appointmentDate.month, a.appointmentDate.day);
                    return a.status == AppointmentStatus.rejected && aptDay.isAtSameMomentAs(todayDay);
                 }).toList();

                 if (rejectedToday.isNotEmpty) {
                    rejectedToday.sort((a,b) => a.createdAt.compareTo(b.createdAt));
                    final lastRejected = rejectedToday.last;
                    return _buildRejectedStatus(lastRejected, l10n, locale);
                 }
                 return _buildMessage(Icons.event_note, l10n.noPendingAppointments);
              }

              final withToken = activeAppointments.where((a) => a.tokenNumber > 0).toList();
              AppointmentModel myAppointment;
              
              if (withToken.isNotEmpty) {
                 withToken.sort((a, b) {
                   if (a.status == AppointmentStatus.serving && b.status != AppointmentStatus.serving) return 1;
                   if (a.status != AppointmentStatus.serving && b.status == AppointmentStatus.serving) return -1;
                   return a.tokenNumber.compareTo(b.tokenNumber);
                 });
                 myAppointment = withToken.last; 
              } else {
                 activeAppointments.sort((a,b) => a.createdAt.compareTo(b.createdAt));
                 myAppointment = activeAppointments.last;
              }

              if (myAppointment.tokenNumber <= 0 || myAppointment.status == AppointmentStatus.pending) {
                 return _buildMessage(Icons.hourglass_empty, l10n.waitingForApproval, subtext: l10n.queueNotActive);
              }

              final doctorMap = doctors.firstWhere(
                (d) => d['name_en'] == myAppointment.doctorName,
                orElse: () => {
                   'name_en': myAppointment.doctorName, 
                   'department_en': myAppointment.department,
                   'name_ml': myAppointment.doctorName,
                   'department_ml': myAppointment.department
                }
              );

              // ---------------------------------------------
              // START MONITORING
              // ---------------------------------------------
              // We construct the doc ID to watch
              final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
              final docKey = myAppointment.doctorName.replaceAll(RegExp(r'\s+'), '_');
              final docId = "${dateString}_$docKey";
              
              // Call Service to start watching (Safe to call repeatedly)
              NotificationService().startQueueMonitoring(
                docId, 
                myAppointment.tokenNumber,
                alarmDistance: myAppointment.alarmTokenDistance,
                appointmentId: myAppointment.id,
                alreadyTriggered: myAppointment.alertTriggered
              );

              return StreamBuilder<Map<String, dynamic>>(
                stream: appointmentService.getLiveQueueState(myAppointment.doctorName, today),
                builder: (context, statsSnapshot) {
                   final stats = statsSnapshot.data ?? {'currentToken': 0, 'nextToken': 0};
                   final currentToken = stats['currentToken'] ?? 0;
                   final nextToken = stats['nextToken'] ?? 0;

                   return Center(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.shade100,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: Colors.teal.shade200, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.shade200)
                              ),
                              child: Text(
                                l10n.appointmentApproved.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 12, 
                                  fontWeight: FontWeight.bold, 
                                  color: Colors.green.shade700,
                                  letterSpacing: 1
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              DoctorData.getDoctorName(doctorMap['name_en'] ?? myAppointment.doctorName, locale),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              DoctorData.getDoctorDepartment(doctorMap['department_en'] ?? myAppointment.department, locale),
                              style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${l10n.date}: ${DateFormat('EEEE, MMM d, yyyy', locale).format(myAppointment.appointmentDate)}", 
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                            ),
                            const SizedBox(height: 30),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildElderlyInfoItem(l10n.currentToken, "$currentToken", Colors.teal),
                                Container(width: 1, height: 50, color: Colors.grey.shade300),
                                _buildElderlyInfoItem(l10n.nextToken, "$nextToken", Colors.blue),
                              ],
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Alert if Near Turn
                            // Logic: Relies on NotificationService to trigger sound & update persistence
                            // We just display the UI based on state
                            Builder(
                              builder: (context) {
                                final int dist = myAppointment.alarmTokenDistance ?? NotificationService().tokenAlertThreshold;
                                final int cToken = currentToken is int ? currentToken : (currentToken as num).toInt();
                                final int diff = myAppointment.tokenNumber - cToken;
                                
                                // 1. Check Display Condition (STRICT EXACT MATCH)
                                final bool conditionMet = diff == dist;
                                
                                // 🔊 SOUND TRIGGER LOGIC (New)
                                // Trigger ONLY if condition met, token > current (future), and NOT yet triggered
                                if (conditionMet && diff > 0 && !myAppointment.alertTriggered) {
                                   WidgetsBinding.instance.addPostFrameCallback((_) {
                                      // Double check mounted to prevent errors
                                      if (context.mounted) {
                                         print("LiveQueueScreen: UP NEXT Condition Met. Triggering Sound & Alert...");
                                         
                                         // 1. Ensure Audio Context is ready (best effort)
                                         SoundService.initializeAudio();
                                         
                                         // 2. Play Loop
                                         SoundService.playQueueLoop();
                                         
                                         // 3. Mark as triggered in DB to prevent re-trigger on next build
                                         AppointmentService().markAlertTriggered(myAppointment.id);
                                      }
                                   });
                                }
                                
                                // 2. UI Display
                                if (myAppointment.alertTriggered || (conditionMet && diff > 0)) {
                                  return InkWell(
                                    onTap: () {
                                       // Stop sound immediately
                                       SoundService.stopLoop();
                                       
                                       // REMOVED: Navigation to Live Consultation
                                       // Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveConsultationScreen()));
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 24),
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
                              }
                            ),
                              
                            // User's Token with Highlight
                            Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(16),
                               decoration: BoxDecoration(
                                 color: Colors.orange.shade50,
                                 borderRadius: BorderRadius.circular(16),
                                 border: Border.all(color: Colors.orange.shade200, width: 2)
                               ),
                               child: Column(
                                 children: [
                                   Text(
                                     l10n.yourToken.toUpperCase(), 
                                     style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800, letterSpacing: 1.2)
                                   ),
                                   Text(
                                     "${myAppointment.tokenNumber}",
                                     style: GoogleFonts.outfit(
                                       fontSize: 48, 
                                       fontWeight: FontWeight.w900, 
                                       color: Colors.orange.shade900
                                     ),
                                   )
                                 ],
                               ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              );
            },
          ),
        );
      }
    );

    if (widget.embed) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.liveQueue,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Listener(
        onPointerDown: (_) => SoundService.initializeAudio(),
        child: content
      ),
    );
  }

  Widget _buildRejectedStatus(AppointmentModel appointment, AppLocalizations l10n, String locale) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade100.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.red.shade200, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cancel_rounded, color: Colors.red.shade600, size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.appointmentRejected.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.red.shade800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                DoctorData.getDoctorName(appointment.doctorName, locale),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.department,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              Text(
                DoctorData.getDoctorDepartment(appointment.department, locale),
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.date,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              Text(
                DateFormat('EEEE, MMM d, yyyy', locale).format(appointment.appointmentDate),
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.noActiveQueueDesc,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(IconData icon, String message, {String? subtext}) {
    return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(icon, size: 60, color: Colors.grey.shade400),
           const SizedBox(height: 16),
           Text(
             message,
             style: GoogleFonts.outfit(fontSize: 20, color: Colors.grey.shade600),
           ),
           if (subtext != null) ...[
             const SizedBox(height: 8),
             Text(subtext, style: GoogleFonts.outfit(color: Colors.grey)),
           ]
         ],
       ),
     );
  }

  Widget _buildElderlyInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
           value == "0" ? "-" : value,
           style: GoogleFonts.outfit(
             fontSize: 32,
             fontWeight: FontWeight.bold,
             color: color,
           ),
        ),
      ],
    );
  }

  Widget _buildStaffQueueBox(
    BuildContext context,
    Map<String, dynamic> doctor, 
    List<AppointmentModel> appointments,
    AppointmentService service,
    AppLocalizations l10n,
    String locale
  ) {
    // 1. Determine State
    final serving = appointments.where((a) => a.status == AppointmentStatus.serving).toList();
    final int displayToken = serving.isNotEmpty 
        ? serving.first.tokenNumber 
        : 0; 
        
    final rawName = doctor['name_en'] ?? 'Unknown';
    final doctorName = DoctorData.getDoctorName(rawName, locale);
    final department = DoctorData.getDoctorDepartment(doctor['department_en'] ?? '', locale);

    // We need a local state listener for the dropdown. 
    // Since we are in a method of a StatelessWidget, we'll use a local variables isn't enough.
    // We will switch to using a separate widget `StaffQueueBox` for this.
    return _StaffQueueBox(
      doctorName: doctorName,
      department: department,
      rawDoctorName: rawName,
      service: service,
      l10n: l10n,
    );
  }
}

class _StaffQueueBox extends StatefulWidget {
  final String doctorName;
  final String department;
  final String rawDoctorName;
  final AppointmentService service;
  final AppLocalizations l10n;

  const _StaffQueueBox({
    required this.doctorName,
    required this.department,
    required this.rawDoctorName,
    required this.service,
    required this.l10n,
  });

  @override
  State<_StaffQueueBox> createState() => _StaffQueueBoxState();
}

class _StaffQueueBoxState extends State<_StaffQueueBox> {
  int? _selectedToken;

  @override
  Widget build(BuildContext context) {
    // STREAM BUILDER FOR SINGLE SOURCE OF TRUTH
    return StreamBuilder<Map<String, dynamic>>(
      stream: widget.service.getLiveQueueState(widget.rawDoctorName, DateTime.now()),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'currentToken': 0};
        final currentDisplayToken = stats['currentToken'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: currentDisplayToken > 0 ? Colors.teal.shade300 : Colors.grey.shade200, 
              width: currentDisplayToken > 0 ? 2 : 1
            ),
          ),
          child: Column(
            children: [
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.doctorName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18, 
                              color: Colors.teal.shade900,
                            ),
                          ),
                          Text(
                            widget.department,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                         color: Colors.teal.shade50,
                         borderRadius: BorderRadius.circular(10)
                       ),
                       child: Text(
                         "${widget.l10n.currentToken}: ${currentDisplayToken > 0 ? currentDisplayToken : '-'}",
                         style: GoogleFonts.outfit(
                           fontSize: 14, 
                           fontWeight: FontWeight.bold, 
                           color: Colors.teal.shade800
                         ),
                       ),
                    )
                 ],
               ),
           const Divider(height: 24),
           Row(
             children: [
                // DECREMENT Button
                _ControlBtn(
                  icon: Icons.remove, 
                  color: Colors.red,
                  onTap: () {
                     widget.service.decrementToken(widget.rawDoctorName, DateTime.now());
                  }
                ),
                const SizedBox(width: 8),

                // Dropdown 1-100
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedToken,
                        hint: Text(
                          _selectedToken == null 
                              ? (currentDisplayToken > 0 ? "$currentDisplayToken" : widget.l10n.setToken)
                              : widget.l10n.setToken, 
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        isExpanded: true,
                        items: List.generate(100, (index) => index + 1).map((val) {
                          return DropdownMenuItem<int>(
                            value: val,
                            child: Text(val.toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                           setState(() {
                             _selectedToken = val;
                           });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // SET Button
                 _ControlBtn(
                  icon: Icons.check, 
                  color: Colors.blue,
                  label: "Set",
                  onTap: () {
                    if (_selectedToken != null) {
                       widget.service.jumpToToken(widget.rawDoctorName, DateTime.now(), _selectedToken!);
                       setState(() { _selectedToken = null; }); // Reset selection after set
                    }
                  }
                ),
                const SizedBox(width: 8),
                // INCREMENT Button
                _ControlBtn(
                  icon: Icons.add, 
                  color: Colors.green,
                  onTap: () {
                    widget.service.incrementToken(widget.rawDoctorName, DateTime.now());
                  }
                ),
             ],
           ),
        ],
      ),
        );
      },
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;

  const _ControlBtn({required this.icon, required this.color, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(label!, style: TextStyle(color: color, fontWeight: FontWeight.bold))
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// LIVE CONSULTATION SCREEN (Added as requested)
// ---------------------------------------------------------
