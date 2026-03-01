import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalRecord {
  final String id;
  final String title;
  final String description;
  final String department;
  final String doctorId;
  final String doctorName;
  final DateTime recordDate;
  final DateTime uploadDate;
  final int fileSize;
  final String fileType;
  final String fileUrl;
  final String uploadedByRole;
  final String elderlyId;
  final bool isActive;

  MedicalRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.doctorId,
    required this.doctorName,
    required this.recordDate,
    required this.uploadDate,
    required this.fileSize,
    required this.fileType,
    required this.fileUrl,
    required this.uploadedByRole,
    required this.elderlyId,
    required this.isActive,
  });

  factory MedicalRecord.fromMap(Map<String, dynamic> data, String documentId) {
    return MedicalRecord(
      id: documentId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      department: data['department'] ?? '',
      doctorId: data['doctorId'] ?? '',
      doctorName: data['doctorName'] ?? '',
      recordDate:
          (data['recordDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploadDate:
          (data['uploadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fileSize: data['fileSize'] as int? ?? 0,
      fileType: data['fileType'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      uploadedByRole: data['uploadedByRole'] ?? '',
      elderlyId: data['elderlyId'] ?? '',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'department': department,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'recordDate': Timestamp.fromDate(recordDate),
      'uploadDate': Timestamp.fromDate(uploadDate),
      'fileSize': fileSize,
      'fileType': fileType,
      'fileUrl': fileUrl,
      'uploadedByRole': uploadedByRole,
      'elderlyId': elderlyId,
      'isActive': isActive,
    };
  }
}
