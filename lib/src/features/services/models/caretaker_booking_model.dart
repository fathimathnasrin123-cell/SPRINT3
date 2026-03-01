import 'package:cloud_firestore/cloud_firestore.dart';

class CaretakerBookingModel {
  final String id;
  final String userId;
  final String uniqueId; // Added for display
  final String userName;
  final String serviceType; // Daily care, Medical assistance, Home support, Emergency help
  final String durationType; // Hourly, Daily, Monthly
  final String status; // Pending, Confirmed, Completed, Cancelled
  final Timestamp requestTime;
  final String? assignedCaretakerId;
  final String? assignedCaretakerName;
  final String? assignedCaretakerContact;
  final String? notes;
  final String? rejectionReason;
  final String? location; // Added
  final String? contactDetails; // Added
  final String? permissionStatus; // Added for auto-link

  CaretakerBookingModel({
    required this.id,
    required this.userId,
    this.uniqueId = '', 
    required this.userName,
    required this.serviceType,
    required this.durationType,
    required this.status,
    required this.requestTime,
    this.assignedCaretakerId,
    this.assignedCaretakerName,
    this.assignedCaretakerContact,
    this.notes,
    this.rejectionReason,
    this.location,
    this.contactDetails,
    this.permissionStatus,
  });

  factory CaretakerBookingModel.fromMap(Map<String, dynamic> data, String id) {
    return CaretakerBookingModel(
      id: id,
      userId: data['userId'] ?? '',
      uniqueId: data['uniqueId'] ?? '',
      userName: data['userName'] ?? 'Unknown User',
      serviceType: data['serviceType'] ?? '',
      durationType: data['durationType'] ?? 'Hourly',
      status: data['status'] ?? 'Pending',
      requestTime: data['requestTime'] ?? Timestamp.now(),
      assignedCaretakerId: data['assignedCaretakerId'],
      assignedCaretakerName: data['assignedCaretakerName'],
      assignedCaretakerContact: data['assignedCaretakerContact'],
      notes: data['notes'],
      rejectionReason: data['rejectionReason'],
      location: data['location'],
      contactDetails: data['contactDetails'],
      permissionStatus: data['permissionStatus'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'uniqueId': uniqueId,
      'userName': userName,
      'serviceType': serviceType,
      'durationType': durationType,
      'status': status,
      'requestTime': requestTime,
      'assignedCaretakerId': assignedCaretakerId,
      'assignedCaretakerName': assignedCaretakerName,
      'assignedCaretakerContact': assignedCaretakerContact,
      'notes': notes,
      'rejectionReason': rejectionReason,
      'location': location,
      'contactDetails': contactDetails,
      'permissionStatus': permissionStatus,
    };
  }
}
