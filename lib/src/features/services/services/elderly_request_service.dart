import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/elderly_request_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ElderlyRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createRequest({
    required String elderlyId,
    required String requestType,
    String? location,
  }) async {
    try {
      final requestData = ElderlyRequestModel(
        id: '', // Firestore generates this
        elderlyId: elderlyId,
        requestType: requestType,
        requestStatus: 'pending',
        location: location,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('elderly_requests').add(requestData.toMap());
    } catch (e) {
      print('Error creating elderly service request: $e');
      rethrow;
    }
  }

  Future<void> updateRequestStatus({
    required String requestId,
    required String newStatus,
  }) async {
    try {
      await _firestore.collection('elderly_requests').doc(requestId).update({
        'request_status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating elderly service request status: $e');
      rethrow;
    }
  }

  Stream<List<ElderlyRequestModel>> getElderlyRequests(String elderlyId) {
    return _firestore
        .collection('elderly_requests')
        .where('elderly_id', isEqualTo: elderlyId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ElderlyRequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<ElderlyRequestModel>> getAllPendingRequests() {
    return _firestore
        .collection('elderly_requests')
        .where('request_status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ElderlyRequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
