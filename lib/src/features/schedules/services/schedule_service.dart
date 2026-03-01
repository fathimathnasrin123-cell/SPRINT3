import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createSchedule({
    required String targetUserId,
    required DateTime scheduleTime,
    required String description,
    String? orderId,
  }) async {
    try {
      final docRef = await _firestore.collection('schedules').add({
        'userId': targetUserId,
        'scheduleTime': Timestamp.fromDate(scheduleTime),
        'description': description,
        'status': 'active',
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid ?? 'system',
      });

      // Send Schedule Creation Notification
      await NotificationService().logNotificationToDb(
        title: 'New Schedule Created',
        message: 'A new schedule has been set for you: $description',
        notificationType: 'schedule_update',
        userId: targetUserId,
        scheduleId: docRef.id,
        orderId: orderId,
        scheduledTime: scheduleTime,
        priority: 'high',
      );
    } catch (e) {
      print('Error creating schedule: $e');
      rethrow;
    }
  }

  Future<void> updateSchedule({
    required String scheduleId,
    required String targetUserId,
    DateTime? newTime,
    String? newDescription,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (newTime != null) updates['scheduleTime'] = Timestamp.fromDate(newTime);
      if (newDescription != null) updates['description'] = newDescription;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      if (updates.isNotEmpty) {
        await _firestore.collection('schedules').doc(scheduleId).update(updates);

        // Send Schedule Change Notification
        await NotificationService().logNotificationToDb(
          title: 'Schedule Updated',
          message: 'Your schedule has been updated. Please check the details.',
          notificationType: 'schedule_update',
          userId: targetUserId,
          scheduleId: scheduleId,
          priority: 'medium',
        );
      }
    } catch (e) {
      print('Error updating schedule: $e');
      rethrow;
    }
  }

  Future<void> cancelSchedule({
    required String scheduleId,
    required String targetUserId,
  }) async {
    try {
      await _firestore.collection('schedules').doc(scheduleId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send Schedule Cancellation Notification
      await NotificationService().logNotificationToDb(
        title: 'Schedule Cancelled',
        message: 'A schedule assigned to you has been cancelled.',
        notificationType: 'schedule_update',
        userId: targetUserId,
        scheduleId: scheduleId,
        priority: 'high',
      );
    } catch (e) {
      print('Error cancelling schedule: $e');
      rethrow;
    }
  }
}
