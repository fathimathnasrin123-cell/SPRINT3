import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:carenow/l10n/app_localizations.dart';
import '../../auth/services/auth_provider.dart';
import '../services/appointment_service.dart';
import '../data/doctor_data.dart'; // Import Doctor Data
import 'package:carenow/src/core/services/notification_service.dart'; // Added
import '../../auth/models/user_model.dart';

class AppointmentBookingScreen extends StatefulWidget {
  final String? targetPatientId;
  final String? targetPatientName;
  const AppointmentBookingScreen({super.key, this.targetPatientId, this.targetPatientName});

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  // Now using DoctorData instead of hardcoded list in state
  final List<Map<String, dynamic>> _allDoctors = DoctorData.doctors;

  void _onDoctorSelected(Map<String, dynamic> doctor, String localizedName) async {
     final l10n = AppLocalizations.of(context)!;
     // Pick Date
     final DateTime? pickedDate = await showDatePicker(
       context: context,
       initialDate: DateTime.now(),
       firstDate: DateTime.now(),
       lastDate: DateTime.now().add(const Duration(days: 30)),
     );

     if (pickedDate != null) {
       // Confirm Dialog
       if (!mounted) return;
       // We can await here if we want to ensure sequentiality, but void return is also fine
       _showConfirmationDialog(doctor, localizedName, pickedDate, l10n);
     }
  }

  void _showConfirmationDialog(Map<String, dynamic> doctor, String localizedName, DateTime date, AppLocalizations l10n) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    int selectedDistance = 3; // Default Fallback, user requested 1 or 3.
    
    if (user != null) {
       await NotificationService().loadUserPreferences(user.id);
       // Only use pref if explicitly set, else keep 3? 
       // Currently NotificationService defaults to 5 internally. 
       // We'll trust NotificationService but maybe override if needed.
       selectedDistance = NotificationService().tokenAlertThreshold;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.confirmAppointment, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${l10n.doctor}: $localizedName", style: GoogleFonts.outfit(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("${l10n.department}: ${DoctorData.getDoctorDepartment(doctor['department_en']!, Localizations.localeOf(context).languageCode)}", style: GoogleFonts.outfit(fontSize: 16)),
                  const SizedBox(height: 8),
                  if (widget.targetPatientName != null)
                     Text("Patient: ${widget.targetPatientName}", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 8),
                  Text("${l10n.date}: ${DateFormat('yyyy-MM-dd', Localizations.localeOf(context).languageCode).format(date)}", style: GoogleFonts.outfit(fontSize: 16)),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text("Alarm / Notification Preference:", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 4),
                  Text("Notify me when my turn is within:", style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedDistance,
                        isExpanded: true,
                        items: List.generate(10, (index) => index + 1).map((val) {
                          return DropdownMenuItem<int>(
                            value: val,
                            child: Text("$val ${val == 1 ? 'Token' : 'Tokens'} Away"),
                          );
                        }).toList(),
                        onChanged: (val) {
                           if (val != null) {
                             setState(() {
                               selectedDistance = val;
                             });
                           }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel, style: const TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _bookAppointment(doctor, date, selectedDistance);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: Text(l10n.confirm),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _bookAppointment(Map<String, dynamic> doctor, DateTime date, [int? alarmTokenDistance]) async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;
    final l10n = AppLocalizations.of(context)!;

    // Use passed details if available, else current user
    final String patientId = widget.targetPatientId ?? currentUser.id;
    final String patientName = widget.targetPatientName ?? currentUser.name;
    // If booking for someone else, the current user is likely the caregiver
    final String? caregiverId = widget.targetPatientId != null ? currentUser.id : null;

    try {
      await AppointmentService().createAppointment(
        patientId: patientId,
        patientName: patientName, 
        caregiverId: caregiverId,
        appointmentDate: date,
        doctorName: doctor['name_en']!, 
        department: doctor['department_en']!,
        timeSlot: "Pending",
        alarmTokenDistance: alarmTokenDistance, 
      );
      
      // Generate Staff Notification
      if (currentUser.role == UserRole.elderly || currentUser.role == UserRole.caregiver) {
        final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
        await NotificationService().logNotificationToDb(
          userId: 'staff_broadcast', // Special ID or can be left blank if targetRole handles it
          title: 'New Appointment Scheduled',
          message: 'Patient $patientName has scheduled an appointment on $formattedDate.',
          notificationType: 'appointment_update',
          targetRole: 'hospitalStaff',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.appointmentBookedSuccess)));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = "Error: $e";
        if (e.toString().contains('activeTokenRestriction')) {
          errorMessage = l10n.activeTokenRestriction;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectDoctor, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _allDoctors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final doctor = _allDoctors[index];
          final localizedName = DoctorData.getDoctorName(doctor['name_en'], locale);

          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: () => _onDoctorSelected(doctor, localizedName),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.teal.shade50,
                      child: Icon(Icons.person, size: 30, color: Colors.teal.shade700),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedName,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DoctorData.getDoctorDepartment(doctor['department_en']!, locale),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
