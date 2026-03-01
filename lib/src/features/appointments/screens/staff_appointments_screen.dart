
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_provider.dart';
import '../models/appointment_model.dart';
import '../services/appointment_service.dart';
import 'package:carenow/l10n/app_localizations.dart';
import '../data/doctor_data.dart';
import 'live_queue_screen.dart';
import '../../appointments/widgets/rejection_dialog.dart'; // Import RejectionDialog

class StaffAppointmentsScreen extends StatefulWidget {
  const StaffAppointmentsScreen({super.key});

  @override
  State<StaffAppointmentsScreen> createState() => _StaffAppointmentsScreenState();
}

class _StaffAppointmentsScreenState extends State<StaffAppointmentsScreen> {
  int _selectedIndex = 0; // 0 for Live Queue, 1 for Requests

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.staffPortal, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // CUSTOM TAB HEADER
          Container(
            color: Colors.teal,
            child: Row(
              children: [
                _buildTabItem(0, l10n.liveQueue, Icons.queue),
                _buildTabItem(1, l10n.appointmentRequests, Icons.assignment_ind),
              ],
            ),
          ),
          // FULL PAGE CONTENT
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                // INDEX 0: LIVE QUEUE
                const LiveQueueScreen(isStaff: true, embed: true),
                // INDEX 1: REQUESTS
                const _RequestsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: isSelected 
                  ? const Border(bottom: BorderSide(color: Colors.white, width: 4))
                  : null,
              color: isSelected ? Colors.teal.shade800 : Colors.teal,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isSelected ? Colors.white : Colors.teal.shade200, size: 28),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : Colors.teal.shade200,
                    fontSize: 18, // Larger text as requested
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection();

  @override
  Widget build(BuildContext context) {
    final appointmentService = AppointmentService();
    final l10n = AppLocalizations.of(context)!;
    final user = Provider.of<AuthProvider>(context).currentUser;
    final locale = Localizations.localeOf(context).languageCode;

    return StreamBuilder<List<AppointmentModel>>(
        stream: appointmentService.getStaffAppointments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.noPendingAppointments, style: const TextStyle(fontSize: 18, color: Colors.grey)));
          }

          final appointments = snapshot.data!;

          return ListView.builder(
            itemCount: appointments.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final apt = appointments[index];
              final doctorName = DoctorData.getDoctorName(apt.doctorName, locale);
              final isPending = apt.status == AppointmentStatus.pending;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                    l10n.patientId, // "Patient ID" label
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                                 ),
                                 Text(
                                   apt.patientName ?? apt.patientId, 
                                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                                 ),
                               ],
                             ),
                           ),
                           Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isPending ? Colors.orange.shade200 : Colors.green.shade200),
                              ),
                              child: Text(
                                _getStatusText(apt.status, l10n).toUpperCase(), 
                                style: TextStyle(
                                  color: isPending ? Colors.orange.shade800 : Colors.green.shade800, 
                                  fontWeight: FontWeight.bold, fontSize: 12
                                ),
                              ),
                           )
                         ],
                       ),
                       const Divider(height: 24),
                       Row(
                         children: [
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(l10n.doctor, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                 const SizedBox(height: 4),
                                 Text(doctorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                               ],
                             )
                           ),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(l10n.department, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                 const SizedBox(height: 4),
                                 Text(
                                   DoctorData.getDoctorDepartment(apt.department, locale), 
                                   style: const TextStyle(fontWeight: FontWeight.w600)
                                 ),
                               ],
                             )
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       // Show Token Number if not pending
                       if (!isPending) ...[
                         Row(
                           children: [
                             Text("${l10n.token}: ", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                             Text(
                               "${apt.tokenNumber}", 
                               style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)
                             ),
                           ],
                         ),
                         const SizedBox(height: 16),
                       ],

                       Text(l10n.date, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                       const SizedBox(height: 4),
                       Text(
                         DateFormat('EEEE, MMMM d, yyyy', locale).format(apt.appointmentDate),
                         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)
                       ),
                       
                       // Only show actions if Pending
                       if (isPending) ...[
                         const SizedBox(height: 24),
                         Row(
                           children: [
                             Expanded(
                               child: OutlinedButton(
                                 onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) {
                                         return RejectionDialog(
                                           onConfirm: (reason) {
                                                appointmentService.updateStatus(
                                                  apt.id, 
                                                  AppointmentStatus.rejected, 
                                                  staffId: user?.id,
                                                  rejectionReason: reason
                                                );
                                           }
                                         );
                                      }
                                    );
                                 },
                                 style: OutlinedButton.styleFrom(
                                   foregroundColor: Colors.red,
                                   side: const BorderSide(color: Colors.red),
                                   padding: const EdgeInsets.symmetric(vertical: 12),
                                 ),
                                 child: Text(l10n.reject),
                               ),
                             ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: ElevatedButton(
                                 onPressed: () {
                                   appointmentService.updateStatus(apt.id, AppointmentStatus.approved, staffId: user?.id);
                                 },
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.green,
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(vertical: 12),
                                 ),
                                 child: Text(l10n.approve),
                               ),
                             ),
                           ],
                         )
                       ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
  }
  String _getStatusText(AppointmentStatus status, AppLocalizations l10n) {
    switch (status) {
      case AppointmentStatus.pending:
        return l10n.pending;
      case AppointmentStatus.approved:
        return l10n.approved;
      case AppointmentStatus.rejected:
        return l10n.rejected;
      case AppointmentStatus.serving:
        return l10n.nowServing; // or "Serving"
      case AppointmentStatus.completed:
        return l10n.complete;
      default:
        return status.name;
    }
  }
}
