import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/medical_record.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<MedicalRecord>> getMedicalRecords(String elderlyId) {
    return _firestore
        .collection('medical_records')
        .where('elderlyId', isEqualTo: elderlyId)
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs
              .map((doc) => MedicalRecord.fromMap(doc.data(), doc.id))
              .where((record) => record.isActive)
              .toList();

          records.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
          return records;
        });
  }

  Future<void> addMedicalRecord({
    required String elderlyId,
    required String title,
    required String description,
    required String doctorId,
    required String doctorName,
    required String department,
    required DateTime recordDate,
    required String uploadedByRole,
    required Uint8List fileBytes,
    required String fileName,
    required int fileSize,
    required String fileType,
  }) async {
    String? fileUrl;
    String filePath =
        'medical_records/$elderlyId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    Reference storageRef = _storage.ref().child(filePath);

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final bucket = 'carenow-19214.firebasestorage.app';
      final encodedPath = Uri.encodeComponent(filePath);
      final uploadUrl = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=$encodedPath',
      );

      // Explicitly using HTTP to prevent silent Web SDK timeouts and satisfy multipart/header rules
      final request = http.Request('POST', uploadUrl);

      if (token != null) {
        request.headers['Authorization'] =
            'Bearer $token'; // Send correct Auth headers
      }

      request.headers['Content-Type'] = fileType.toLowerCase() == 'pdf'
          ? 'application/pdf'
          : 'image/${fileType.toLowerCase() == 'jpg' ? 'jpeg' : fileType.toLowerCase()}';

      // Setting binary body payload
      request.bodyBytes = fileBytes;

      // Strict 30 second timeout instead of infinite background loop
      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        if (response.statusCode == 400)
          throw Exception("Upload failed: Bad Request / Invalid format.");
        if (response.statusCode == 401)
          throw Exception("Upload failed: Unauthorized access.");
        if (response.statusCode == 403)
          throw Exception(
            "Upload failed: Server rejected file (403 Permission Denied or CORS disabled).",
          );
        if (response.statusCode == 413)
          throw Exception("File exceeds server max upload size 15MB limit.");
        throw Exception(
          "Upload failed with server status ${response.statusCode}",
        );
      }

      // Extract specific token ID created for direct download links
      final data = json.decode(responseBody);
      final downloadToken = data['downloadTokens'];
      fileUrl =
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$downloadToken';

      MedicalRecord record = MedicalRecord(
        id: '',
        title: title,
        description: description,
        department: department,
        doctorId: doctorId,
        doctorName: doctorName,
        recordDate: recordDate,
        uploadDate: DateTime.now(),
        fileSize: fileSize,
        fileType: fileType,
        fileUrl: fileUrl,
        uploadedByRole: uploadedByRole,
        elderlyId: elderlyId,
        isActive: true,
      );

      await _firestore
          .collection('medical_records')
          .add(record.toMap())
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      if (fileUrl != null) {
        try {
          // Best effort cleanup via REST
          final encodedPath = Uri.encodeComponent(filePath);
          final token = await FirebaseAuth.instance.currentUser?.getIdToken();
          final deleteReq = http.Request(
            'DELETE',
            Uri.parse(
              'https://firebasestorage.googleapis.com/v0/b/carenow-19214.firebasestorage.app/o/$encodedPath',
            ),
          );
          if (token != null)
            deleteReq.headers['Authorization'] = 'Bearer $token';
          await deleteReq.send();
        } catch (_) {}
      }
      // Provide clean error without standard stack trace prefixes
      final errorStr = e.toString();
      if (errorStr.contains('TimeoutException')) {
        throw Exception(
          "Network timeout. Please check your connection and try again.",
        );
      }
      if (errorStr.contains('XMLHttpRequest error')) {
        throw Exception(
          "Server CORS validation failed or connection blocked. Please verify server headers.",
        );
      }
      throw Exception(errorStr.replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateMedicalRecord(
    String recordId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('medical_records').doc(recordId).update(data);
  }

  Future<void> softDeleteMedicalRecord(String recordId) async {
    await updateMedicalRecord(recordId, {'isActive': false});
  }
}
