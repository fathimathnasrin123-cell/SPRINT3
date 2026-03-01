import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { pending, approved, rejected, serving, completed, cancelled, skipped }

class AppointmentModel {
  final String id;
  final String patientId;
  final String? patientName; // Added
  final String? caregiverName; // Added
  final String doctorName; 
  final String department; 
  final String? caregiverId; 
  final DateTime appointmentDate;
  final String? timeSlot; 
  final int tokenNumber;
  final AppointmentStatus status;
  final DateTime createdAt;
  final int? alarmTokenDistance; // Restored
  final bool alertTriggered; 
  final bool isUpNext; 
  final String? rejectionReason;

  AppointmentModel({
    required this.id,
    required this.patientId,
    this.patientName,
    this.caregiverName,
    required this.doctorName,
    required this.department,
    this.caregiverId,
    required this.appointmentDate,
    this.timeSlot,
    required this.tokenNumber,
    required this.status,
    required this.createdAt,
    this.alarmTokenDistance,
    this.alertTriggered = false,
    this.isUpNext = false,
    this.rejectionReason,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String id) {
    return AppointmentModel(
      id: id,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'],
      caregiverName: map['caregiverName'],
      doctorName: map['doctorName'] ?? 'Unknown Doctor',
      department: map['department'] ?? 'General',
      caregiverId: map['caregiverId'],
      appointmentDate: (map['appointmentDate'] as Timestamp).toDate(),
      timeSlot: map['timeSlot'],
      tokenNumber: map['tokenNumber'] ?? 0,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      alarmTokenDistance: map['alarmTokenDistance'],
      alertTriggered: map['alertTriggered'] ?? false,
      isUpNext: map['isUpNext'] ?? false,
      rejectionReason: map['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'caregiverName': caregiverName,
      'doctorName': doctorName,
      'department': department,
      'caregiverId': caregiverId,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'timeSlot': timeSlot,
      'tokenNumber': tokenNumber,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'alarmTokenDistance': alarmTokenDistance,
      'alertTriggered': alertTriggered,
      'isUpNext': isUpNext,
      'rejectionReason': rejectionReason,
      // Helper for querying by date
      'dateString': "${appointmentDate.year}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}",
    };
  }
}
