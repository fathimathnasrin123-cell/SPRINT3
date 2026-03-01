
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  tokenNear,
  appointmentReminder,
  medicineReminder,
  general
}

enum NotificationStatus {
  pending,
  sent,
  failed,
  read
}

class NotificationModel {
  final String id;
  final String userId;
  final String? targetRole; // For strict role-based filtering
  final String? appointmentId; // Added
  final String? orderId; // Added for orders
  final String? scheduleId; // Added for schedules
  final String? notificationType; // 'token_near', 'appointment_reminder', 'system_alert', 'order_update', 'schedule_update'
  final String title;
  final String message; // Mapped from 'body'
  final String? relatedTokenNumber;
  final String? doctorName;
  final String? department; // Added
  final DateTime scheduledTime;
  final DateTime createdAt; // Added
  final DateTime? sentAt; // Renamed from sentTime
  final String status; // pending, sent, failed
  final bool isRead;
  final String priority; // 'critical', 'high', 'medium'

  NotificationModel({
    required this.id,
    required this.userId,
    this.targetRole,
    this.appointmentId,
    this.orderId,
    this.scheduleId,
    required this.notificationType,
    required this.title,
    required this.message,
    this.relatedTokenNumber,
    this.doctorName,
    this.department,
    required this.scheduledTime,
    required this.createdAt,
    this.sentAt,
    this.status = 'pending',
    this.isRead = false,
    this.priority = 'medium',
  });

  factory NotificationModel.fromMap(Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id,
      userId: data['userId'] ?? '',
      targetRole: data['targetRole'],
      appointmentId: data['appointmentId'],
      orderId: data['orderId'],
      scheduleId: data['scheduleId'],
      notificationType: data['type'] ?? data['notificationType'] ?? 'system_alert', // Map 'type' from DB
      title: data['title'] ?? '',
      message: data['message'] ?? data['body'] ?? '',
      relatedTokenNumber: data['relatedTokenNumber'],
      doctorName: data['doctorName'],
      department: data['department'],
      scheduledTime: data['scheduledTime'] != null ? (data['scheduledTime'] as Timestamp).toDate() : DateTime.now(),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      sentAt: data['sentAt'] != null ? (data['sentAt'] as Timestamp).toDate() : null,
      status: data['status'] ?? 'pending',
      isRead: data['isRead'] ?? false,
      priority: data['priority'] ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'targetRole': targetRole,
      'appointmentId': appointmentId,
      'orderId': orderId,
      'scheduleId': scheduleId,
      'type': notificationType, // Map to 'type' for DB
      'title': title,
      'message': message,
      'relatedTokenNumber': relatedTokenNumber,
      'doctorName': doctorName,
      'department': department,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'status': status,
      'isRead': isRead,
      'priority': priority,
    };
  }
}
