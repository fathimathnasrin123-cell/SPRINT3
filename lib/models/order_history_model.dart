import 'package:cloud_firestore/cloud_firestore.dart';

class OrderHistoryRecord {
  final String id;
  final String orderId;
  final String previousState;
  final String newState;
  final DateTime timestamp;
  final String changedBy;
  final String remarks;

  OrderHistoryRecord({
    required this.id,
    required this.orderId,
    required this.previousState,
    required this.newState,
    required this.timestamp,
    required this.changedBy,
    this.remarks = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'previousState': previousState,
      'newState': newState,
      'timestamp': Timestamp.fromDate(timestamp),
      'changedBy': changedBy,
      'remarks': remarks,
    };
  }

  factory OrderHistoryRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderHistoryRecord(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      previousState: data['previousState'] ?? '',
      newState: data['newState'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      changedBy: data['changedBy'] ?? '',
      remarks: data['remarks'] ?? '',
    );
  }
}
