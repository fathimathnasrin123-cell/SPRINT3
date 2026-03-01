import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/order_history_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/notification_service.dart';
import 'delivery_notification_manager.dart'; // Import Manager

class OrderHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> recordStateChange({
    required String orderId,
    required String previousState,
    required String newState,
    required String customerId, // Added customer ID to know who to notify
    String? remarks,
  }) async {
    try {
      final user = _auth.currentUser;
      final changedBy = user?.uid ?? 'system';

      final record = OrderHistoryRecord(
        id: '', // Firestore will auto-generate this document ID
        orderId: orderId,
        previousState: previousState,
        newState: newState,
        timestamp: DateTime.now(),
        changedBy: changedBy,
        remarks: remarks ?? '',
      );

      await _firestore.collection('order_history').add(record.toMap());

      // Let the modular Delivery Notification Manager handle all dispatches gracefully
      await DeliveryNotificationManager().notifyStatusChange(
        orderId: orderId,
        newStatus: newState,
        targetUserId: customerId,
      );

    } catch (e) {
      print('Error recording order history: $e');
      rethrow;
    }
  }

  Future<List<OrderHistoryRecord>> getOrderHistory(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('order_history')
          .where('orderId', isEqualTo: orderId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => OrderHistoryRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting order history: $e');
      return [];
    }
  }
}
