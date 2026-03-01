import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SharedMedicalDocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<QuerySnapshot> getMedicalDocuments(String elderlyId) {
    return _firestore
        .collection('medical_documents')
        .doc(elderlyId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  Future<void> uploadMedicalDocument({
    required String elderlyId,
    required String fileName,
    required Uint8List fileBytes,
    required String fileType,
    required String uploadedById,
    required String uploadedByName,
    required String uploadedByRole,
  }) async {
    String? fileUrl;
    String filePath =
        'medical_documents/$elderlyId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final bucket =
          'carenow-19214.firebasestorage.app'; // Using existing bucket
      final encodedPath = Uri.encodeComponent(filePath);
      final uploadUrl = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=$encodedPath',
      );

      final request = http.Request('POST', uploadUrl);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.headers['Content-Type'] = fileType.toLowerCase() == 'pdf'
          ? 'application/pdf'
          : 'image/${fileType.toLowerCase() == 'jpg' ? 'jpeg' : fileType.toLowerCase()}';

      request.bodyBytes = fileBytes;

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        if (response.statusCode == 400)
          throw Exception("Upload failed: Bad Request.");
        if (response.statusCode == 401)
          throw Exception("Upload failed: Unauthorized access.");
        if (response.statusCode == 403)
          throw Exception("Upload failed: Permission Denied.");
        if (response.statusCode == 413)
          throw Exception("File exceeds server max upload size limit.");
        throw Exception(
          "Upload failed with server status ${response.statusCode}",
        );
      }

      final data = json.decode(responseBody);
      final downloadToken = data['downloadTokens'];
      fileUrl =
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media&token=$downloadToken';

      final docRef = _firestore
          .collection('medical_documents')
          .doc(elderlyId)
          .collection('documents')
          .doc();

      await docRef.set({
        'fileName': fileName,
        'fileUrl': fileUrl,
        'uploadedById': uploadedById,
        'uploadedByName': uploadedByName,
        'uploadedByRole': uploadedByRole,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error uploading shared document: $e");
      rethrow;
    }
  }
}
