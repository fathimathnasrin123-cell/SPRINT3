import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';



class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'sos_requests';

  // Raise an Emergency Alert
  Future<void> raiseEmergency({
    required String patientId,
    required String patientName,
    String? patientUniqueId,
    String triggeredBy = 'ELDERLY', // 'ELDERLY' or 'CARE_GIVER'
    String? caregiverId,
  }) async {
    try {
      String finalUniqueId = patientUniqueId ?? 'Unknown';

      // If uniqueId not provided, try to fetch it
      if (patientUniqueId == null || patientUniqueId.isEmpty) {
        try {
          final userDoc = await _firestore.collection('users').doc(patientId).get();
          if (userDoc.exists) {
            finalUniqueId = userDoc.data()?['uniqueId'] ?? 'Unknown';
          }
        } catch (e) {
          if (kDebugMode) print("Error fetching uniqueId: $e");
        }
      }

      // 1. Attempt to find connected caregiver if not provided
      String caregiverName = "No caregiver assigned";
      if (caregiverId != null) {
          // If triggered by caregiver, we likely know their ID. fetch name or assume known?
          // For now, let's keep the automatic lookup or standard "Unknown" if not explicit.
          // But if triggeredBy is Caregiver, we should store that ID.
      }
      
      try {
        final cgSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'caregiver')
            .where('linkedElderlyIds', arrayContains: patientId)
            .limit(1)
            .get();
        
        if (cgSnapshot.docs.isNotEmpty) {
          caregiverName = cgSnapshot.docs.first.data()['name'] ?? "Unknown Caregiver";
        }
      } catch (e) {
        if (kDebugMode) print("Error finding caregiver: $e");
      }

      // 2. Notify Caregiver Logic (Safe, Fire-and-Forget)
      // Only notify caregiver if triggered by ELDERLY (if trigger by caregiver, they know)
      if (triggeredBy == 'ELDERLY') {
          _notifyCaregiverSafely(patientId, patientName, finalUniqueId);
      }

      // 3. Get Location (Live GPS)
      String locationString = 'Unknown';
      GeoPoint? geoPoint;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          locationString = "${position.latitude}, ${position.longitude}";
          geoPoint = GeoPoint(position.latitude, position.longitude);
        } else {
          locationString = "Location Permission Denied";
        }
      } catch (e) {
        if (kDebugMode) print("Error getting location: $e");
        locationString = "Location Not Available";
      }

      await _firestore.collection(collectionName).add({
        'patientId': patientId,
        'patientUniqueId': finalUniqueId, // Store the ELD-XXX ID
        'patientName': patientName,
        'caregiverName': caregiverName,
        'caregiverId': caregiverId, // Optional: The specific caregiver who triggered it
        'triggeredBy': triggeredBy,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'PENDING', 
        'location': locationString,
        'geoPoint': geoPoint, 
      });
      
      // Notification to Staff
      await _firestore.collection('notifications').add({
        'userId': 'staff', 
        'type': 'critical',
        'title': 'EMERGENCY ALERT',
        'message': '$patientName ($finalUniqueId) has raised a medical emergency! (Triggered by $triggeredBy)',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'PENDING' 
      });
    } catch (e) {
      if (kDebugMode) print("Error raising emergency: $e");
      rethrow;
    }
  }

  // Helper to notify linked caregiver without blocking main flow
  Future<void> _notifyCaregiverSafely(String patientId, String patientName, String uniqueId) async {
    try {
        // Find linked caregiver
        final query = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'caregiver')
            .where('linkedElderlyIds', arrayContains: patientId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
           final caregiverDoc = query.docs.first;
           final caregiverId = caregiverDoc.id;
           
           // Send Notification
           await _firestore.collection('notifications').add({
              'userId': caregiverId,
              'type': 'emergency_alert', // Caregiver specific type
              'title': 'EMERGENCY: $patientName',
              'message': '$patientName ($uniqueId) has requested emergency assistance.',
              'patientName': patientName,
              'patientId': patientId,
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
              'status': 'sent'
           });
        }
    } catch (e) {
       // Log but DO NOT throw. Caregiver notification failure shouldn't stop staff alert.
       if (kDebugMode) print("Failed to notify caregiver: $e");
    }
  }

  // Accept (Staff) => ACCEPTED
  Future<void> acceptEmergency(String emergencyId, String staffId) async {
    await _updateStatus(emergencyId, 'ACCEPTED', staffId);
  }

  // Reject (Staff) => REJECTED
  Future<void> rejectEmergency(String emergencyId, String staffId) async {
    await _updateStatus(emergencyId, 'REJECTED', staffId);
  }

  // Resolve (Staff) => RESOLVED
  Future<void> resolveEmergency(String emergencyId, String staffId) async {
    await _updateStatus(emergencyId, 'RESOLVED', staffId);
  }

  Future<void> _updateStatus(String id, String status, String staffId) async {
    try {
      await _firestore.collection(collectionName).doc(id).update({
        'status': status,
        'updatedBy': staffId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
       if (kDebugMode) print("Error updating status: $e");
       rethrow;
    }
  }

  // Stream for Staff: ONLY PENDING (for the Blocking Alert Overlay)
  Stream<QuerySnapshot> getPendingEmergenciesStream() {
    return _firestore
        .collection(collectionName)
        .where('status', isEqualTo: 'PENDING')
        .snapshots();
  }

  // Stream for Elderly: Their active requests
  Stream<QuerySnapshot> getElderlyEmergencyStream(String patientId) {
    return _firestore
        .collection(collectionName)
        .where('patientId', isEqualTo: patientId)
        .snapshots();
  }
}


