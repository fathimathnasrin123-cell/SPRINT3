import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerRequestModel {
  final String id;
  final String userId;
  final String uniqueId; // Added for display
  final String userName; // For staff view
  final String serviceType; // Medicine pickup, Daily errands, Basic support
  final String status; // Pending, Approved, Completed, Rejected
  final Timestamp requestTime;
  final String? assignedVolunteerId;
  final String? assignedVolunteerName;
  final String? assignedVolunteerContact;
  final String? notes;
  final String? rejectionReason;
  final String? location; // Added
  final String? description; // Added
  final String? contactDetails; // Added

  VolunteerRequestModel({
    required this.id,
    required this.userId,
    this.uniqueId = '', 
    required this.userName,
    required this.serviceType,
    required this.status,
    required this.requestTime,
    this.assignedVolunteerId,
    this.assignedVolunteerName,
    this.assignedVolunteerContact,
    this.notes,
    this.rejectionReason,
    this.location,
    this.description,
    this.contactDetails,
  });

  factory VolunteerRequestModel.fromMap(Map<String, dynamic> data, String id) {
    return VolunteerRequestModel(
      id: id,
      userId: data['userId'] ?? '',
      uniqueId: data['uniqueId'] ?? '',
      userName: data['userName'] ?? 'Unknown User',
      serviceType: data['serviceType'] ?? '',
      status: data['status'] ?? 'Pending',
      requestTime: data['requestTime'] ?? Timestamp.now(),
      assignedVolunteerId: data['assignedVolunteerId'],
      assignedVolunteerName: data['assignedVolunteerName'],
      assignedVolunteerContact: data['assignedVolunteerContact'],
      notes: data['notes'],
      rejectionReason: data['rejectionReason'],
      location: data['location'],
      description: data['description'],
      contactDetails: data['contactDetails'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'uniqueId': uniqueId,
      'userName': userName,
      'serviceType': serviceType,
      'status': status,
      'requestTime': requestTime,
      'assignedVolunteerId': assignedVolunteerId,
      'assignedVolunteerName': assignedVolunteerName,
      'assignedVolunteerContact': assignedVolunteerContact,
      'notes': notes,
      'rejectionReason': rejectionReason,
      'location': location,
      'description': description,
      'contactDetails': contactDetails,
    };
  }
}
