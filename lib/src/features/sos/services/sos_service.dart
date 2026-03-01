import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SOSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionStream;

  // 🔹 Trigger SOS (Non-blocking Location)
  Future<void> triggerSOS({required String role, String? overrideUserId}) async {
    final user = _auth.currentUser;
    if (user == null) throw "User not logged in";

    final targetUserId = overrideUserId ?? user.uid;

    final docRef = _firestore.collection('sos_requests').doc();
    
    // 1. Create SOS immediately (Status: PENDING)
    await docRef.set({
      'sosId': docRef.id,
      'userId': targetUserId, // Who is in trouble
      'reporterId': user.uid, // Who pressed the button
      'triggeredBy': role, // 'elderly' or 'caregiver'
      'status': 'PENDING',
      'locationStatus': 'pending', // pending | available | not_available
      'timestamp': FieldValue.serverTimestamp(),
      'latitude': null,
      'longitude': null,
    });
    
    // 1.5 Notify Caregivers (Client-Side trigger for speed/reliability without Cloud Functions deployment)
    try {
      final caregivers = await _firestore.collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('linkedElderlyIds', arrayContains: targetUserId)
          .get();
          
      final batch = _firestore.batch();
      
      // Get Reporter Name
      String reporterName = "Elderly";
      final reporterDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (reporterDoc.exists) {
         reporterName = reporterDoc.data()?['name'] ?? "Elderly";
      }

      for (var caregiver in caregivers.docs) {
          final notifRef = _firestore.collection('notifications').doc();
          batch.set(notifRef, {
             'userId': caregiver.id,
             'title': '🚨 Emergency SOS Alert',
             'message': '$reporterName has triggered an emergency SOS. Tap to open immediately.',
             'type': 'sos', // Triggers logic in App & Cloud Function
             'priority': 'critical',
             'isRead': false,
             'createdAt': FieldValue.serverTimestamp(),
             'status': 'pending',
             'sosId': docRef.id, // Link to SOS
             'targetUserId': targetUserId
          });
      }
      if (caregivers.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      print("Error sending SOS notifications: $e");
    }

    // 2. Request Location Permission & Update (Fire & Forget)
    _handleLocationUpdate(docRef.id);
  }

  // 🔹 Handle Location Logic Independently
  Future<void> _handleLocationUpdate(String sosId) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permission Denied
           await _firestore.collection('sos_requests').doc(sosId).update({
            'locationStatus': 'not_available',
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
         await _firestore.collection('sos_requests').doc(sosId).update({
            'locationStatus': 'not_available',
         });
         return;
      }

      // Permission Granted -> Get Position
      // 1. Get immediate position with timeout
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 8), onTimeout: () {
             throw TimeoutException("GPS timed out");
          });
      
      await _firestore.collection('sos_requests').doc(sosId).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationStatus': 'available',
      });

      // 2. Listen for updates while SOS is PENDING
      _startLiveFastLocationUpdates(sosId);

    } catch (e) {
      print("Location Error: $e");
      await _firestore.collection('sos_requests').doc(sosId).update({
        'locationStatus': 'not_available',
      });
    }
  }

  // 🔹 Continuous Location Updates (While Pending)
  void _startLiveFastLocationUpdates(String sosId) {
    _positionStream?.cancel();
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) async {
        if (position != null) {
           // Check if SOS is still active
           final docSpan = await _firestore.collection('sos_requests').doc(sosId).get();
           if (docSpan.exists && docSpan.data()!['status'] == 'PENDING') {
              await _firestore.collection('sos_requests').doc(sosId).update({
                'latitude': position.latitude,
                'longitude': position.longitude,
              });
           } else {
             // Stop updates if not pending
             stopLocationUpdates();
           }
        }
      },
      onError: (e) {
        print("Live Location Error: $e");
      }
    );
  }

  void stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  // 🔹 Stream for Staff (All Pending SOS)
  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingSOSStream() {
    return _firestore
        .collection('sos_requests')
        .where('status', isEqualTo: 'PENDING')
        .snapshots();
  }
  
  // 🔹 Stream for Caregiver (Specific Elderly SOS)
  Stream<QuerySnapshot<Map<String, dynamic>>> getCaregiverSOSStream(List<String> linkedElderlyIds) {
    if (linkedElderlyIds.isEmpty) return Stream.empty();
    
    return _firestore
        .collection('sos_requests')
        .where('userId', whereIn: linkedElderlyIds)
        .where('status', whereIn: ['PENDING', 'ACCEPTED', 'APPROVED', 'RESOLVED'])
        .snapshots();
  }

  // 🔹 Staff Actions (Accept/Resolve)
  Future<void> updateSOSStatus(String sosId, String newStatus, String staffId) async {
     await _firestore.collection('sos_requests').doc(sosId).update({
       'status': newStatus,
       'respondedBy': staffId,
       'responseTimestamp': FieldValue.serverTimestamp(),
     });
     
     if (['ACCEPTED', 'REJECTED', 'RESOLVED'].contains(newStatus)) {
       stopLocationUpdates();
     }
  }
  // 🔹 Stream for User's Own SOS (Status Box)
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserSOSStream(String userId) {
    return _firestore
        .collection('sos_requests')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }
}
