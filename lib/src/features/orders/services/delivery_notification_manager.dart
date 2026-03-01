import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/notification_service.dart';

/// Abstract strategy for modular notification delivery (Push, SMS, Email, etc.)
abstract class NotificationSender {
  Future<void> send(String userId, String title, String message, String type, String orderId);
}

/// Standard In-App & OS Push Notification utilizing our existing system
class PushNotificationSender implements NotificationSender {
  @override
  Future<void> send(String userId, String title, String message, String type, String orderId) async {
    await NotificationService().logNotificationToDb(
      title: title,
      message: message,
      notificationType: type,
      userId: userId,
      orderId: orderId,
      priority: 'high', // Delivery updates need high priority
    );
  }
}

/// Scalable placeholder for future SMS API integration (Twilio/AWS SNS)
class SmsNotificationSender implements NotificationSender {
  @override
  Future<void> send(String userId, String title, String message, String type, String orderId) async {
    print("Mock SMS Sent -> User: $userId, Msg: $message");
  }
}

/// Scalable placeholder for future Email API integration (SendGrid/Mailgun)
class EmailNotificationSender implements NotificationSender {
  @override
  Future<void> send(String userId, String title, String message, String type, String orderId) async {
    print("Mock Email Sent -> User: $userId, Subject: $title");
  }
}

/// Core Manager managing notification dispatches gracefully
class DeliveryNotificationManager {
  static final DeliveryNotificationManager _instance = DeliveryNotificationManager._internal();
  factory DeliveryNotificationManager() => _instance;
  DeliveryNotificationManager._internal();

  // Modular channels - Add/Remove seamlessly. (In-App is mandatory)
  final List<NotificationSender> _senders = [
    PushNotificationSender(),
    // SmsNotificationSender(), // Future activation
    // EmailNotificationSender(), // Future activation
  ];
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> notifyStatusChange({
    required String orderId, 
    required String newStatus, 
    required String targetUserId
  }) async {
    try {
      // 1. Duplicate Prevention Guard
      // Query firestore to check if this exact status was already broadcasted for this order
      final dupCheck = await _firestore.collection('delivery_notification_logs')
        .where('orderId', isEqualTo: orderId)
        .where('status', isEqualTo: newStatus)
        .where('userId', isEqualTo: targetUserId)
        .get();
        
      if (dupCheck.docs.isNotEmpty) {
        print("Delivery Notification Manager: Suppressing duplicate alert for $orderId ($newStatus)");
        return; 
      }

      // 2. Format Contextual Message
      String title = "Delivery Update";
      String message = "Your delivery order #$orderId has been updated to: $newStatus.";
      
      switch (newStatus.toLowerCase()) {
         case 'created':
         case 'pending':
            title = "Order Created";
            message = "Your order #$orderId has been successfully created and is waiting for assignment.";
            break;
         case 'assigned':
         case 'accepted':
            title = "Order Assigned";
            message = "A helper has been assigned to your order #$orderId.";
            break;
         case 'picked up':
         case 'on the way':
            title = "Order Picked Up";
            message = "Your order #$orderId is on the way to you!";
            break;
         case 'delivered':
         case 'completed':
            title = "Order Delivered";
            message = "Your order #$orderId has been delivered successfully.";
            break;
         case 'cancelled':
         case 'rejected':
            title = "Order Cancelled";
            message = "Unfortunately, your order #$orderId was cancelled.";
            break;
      }
      
      // 3. Dispatch to all active configured delivery channels
      for (var sender in _senders) {
        try {
           await sender.send(targetUserId, title, message, 'order_update', orderId);
        } catch (dispatchErr) {
           print("Failed on specific sender: $dispatchErr");
           // Notice we don't rethrow here so one failing channel doesn't break the whole loop 
           // (Graceful error handling)
        }
      }
      
      // 4. Log completion payload to prevent duplicates next time
      await _firestore.collection('delivery_notification_logs').add({
         'orderId': orderId,
         'status': newStatus,
         'userId': targetUserId,
         'timestamp': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      // Catch overarching errors gracefully so the main app isn't crashed
      print("Critical error in Delivery Notification Manager: $e");
    }
  }
}
