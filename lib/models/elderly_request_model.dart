import 'package:cloud_firestore/cloud_firestore.dart';

class ElderlyRequestModel {
  final String id; // request_id
  final String elderlyId; // elderly_id
  final String requestType; // request_type
  final String requestStatus; // request_status: pending, approved, in_progress, completed, cancelled
  final String? location; // location details
  final DateTime createdAt; // created_at
  final DateTime updatedAt; // updated_at

  ElderlyRequestModel({
    required this.id,
    required this.elderlyId,
    required this.requestType,
    required this.requestStatus,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'elderly_id': elderlyId,
      'request_type': requestType,
      'request_status': requestStatus,
      'location': location,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  factory ElderlyRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return ElderlyRequestModel(
      id: docId,
      elderlyId: map['elderly_id'] ?? '',
      requestType: map['request_type'] ?? '',
      requestStatus: map['request_status'] ?? 'pending',
      location: map['location'],
      createdAt: map['created_at'] != null 
          ? (map['created_at'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? (map['updated_at'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}
