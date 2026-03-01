import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import 'package:carenow/src/core/services/notification_service.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _appointmentsRef => _firestore.collection('appointments');
  CollectionReference get _countersRef => _firestore.collection('daily_counters');

  /// Creates a new appointment.
  Future<void> createAppointment({
    required String patientName, 
    String? caregiverName, 
    required String patientId,
    required DateTime appointmentDate,
    required String doctorName,
    required String department,
    String? timeSlot,
    String? caregiverId,
    int? alarmTokenDistance,
  }) async {
    // 0. Check if patient already has an active token (pending, serving, approved)
    // STRICT RULE: If Rejected, user CAN book again. So we do NOT include 'rejected' in this check.
    final activeStatuses = [
      AppointmentStatus.pending.name,
      AppointmentStatus.approved.name,
      AppointmentStatus.serving.name
    ];
    
    final existingDocs = await _appointmentsRef
        .where('patientId', isEqualTo: patientId) 
        .where('status', whereIn: activeStatuses)
        .get();

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    if (existingDocs.docs.isNotEmpty) {
      bool hasActive = false;
      for (var doc in existingDocs.docs) {
         final data = doc.data() as Map<String, dynamic>;
         final aptDate = (data['appointmentDate'] as Timestamp).toDate();
         final aptDay = DateTime(aptDate.year, aptDate.month, aptDate.day);
         
         if (aptDay.isBefore(today)) {
            // Expire old appointment
            doc.reference.update({'status': AppointmentStatus.cancelled.name}); 
         } else {
            // Found an active appointment (Pending or Approved) for Today or Future
            hasActive = true;
         }
      }
      
      if (hasActive) {
         throw Exception('activeTokenRestriction'); 
      }
    }

    // 3. Create Appointment
    final newAppointmentRef = _appointmentsRef.doc();
    final appointment = AppointmentModel(
      id: newAppointmentRef.id,
      patientId: patientId, 
      patientName: patientName, 
      caregiverName: caregiverName, 
      doctorName: doctorName,
      department: department,
      caregiverId: caregiverId,
      appointmentDate: appointmentDate,
      timeSlot: timeSlot,
      tokenNumber: 0, 
      status: AppointmentStatus.pending,
      createdAt: DateTime.now(),
      alarmTokenDistance: alarmTokenDistance,
    );
    
    await newAppointmentRef.set(appointment.toMap());
  }

  /// Stream of appointments for a specific day, ordered by token.
  Stream<List<AppointmentModel>> getLiveQueue(DateTime date) {
    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    return _appointmentsRef
        .where('dateString', isEqualTo: dateString)
        // .orderBy('tokenNumber', descending: false) // Client-side sort to avoid Missing Index issues
        .snapshots()
        .map((snapshot) {
            final docs = snapshot.docs
              .map((doc) => AppointmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
            docs.sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber));
            return docs;
        });
  }

  /// Update appointment status (e.g., to 'serving' or 'completed')
  Future<void> updateStatus(String appointmentId, AppointmentStatus status, {String? staffId, String? rejectionReason}) async {
    
    if (status == AppointmentStatus.approved) {
      await _approveAndGenerateToken(appointmentId, staffId);
    } else {
      final Map<String, dynamic> updateData = {'status': status.name};
      if (staffId != null) {
        updateData['caregiverId'] = staffId; 
      }
      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }
      await _appointmentsRef.doc(appointmentId).update(updateData);
    }
  }

  Future<void> _approveAndGenerateToken(String appointmentId, String? staffId) async {
    final docRef = _appointmentsRef.doc(appointmentId);
    
    await _firestore.runTransaction((transaction) async {
       final snapshot = await transaction.get(docRef);
       if (!snapshot.exists) throw Exception("Appointment not found");
       
       final data = snapshot.data() as Map<String, dynamic>;
       final currentStatus = data['status'];
       
       // Only generate if not already approved/has token?
       // We assume if calling approve, we want to assign/reassign token? 
       // Better to check if token is 0.
       final int existingToken = data['tokenNumber'] ?? 0;
       
       if (existingToken > 0 && currentStatus == AppointmentStatus.approved.name) {
          // Already approved with token
          return; 
       }

       final timestamp = data['appointmentDate'] as Timestamp;
       final appointmentDate = timestamp.toDate();
       final doctorName = data['doctorName'] as String;
       
       // Token Logic
       final dateString = "${appointmentDate.year}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}";
       final doctorKey = doctorName.replaceAll(RegExp(r'\s+'), '_'); 
       final counterDocId = "${dateString}_$doctorKey";
       final counterDocRef = _countersRef.doc(counterDocId);
       
       final counterSnapshot = await transaction.get(counterDocRef);
       int currentCount = 0;
       if (counterSnapshot.exists) {
         currentCount = (counterSnapshot.data() as Map)['count'] ?? 0;
       }
       final newToken = currentCount + 1;
       
       transaction.set(counterDocRef, {'count': newToken}, SetOptions(merge: true));
       


// ... (Inside _approveAndGenerateToken)

       final Map<String, dynamic> updateData = {
         'status': AppointmentStatus.approved.name,
         'tokenNumber': newToken,
       };
       if (staffId != null) {
         updateData['caregiverId'] = staffId;
       }
       
       transaction.update(docRef, updateData);

       // NOTIFICATION LOGIC: Approved & Token Assigned
       // Note: We cannot await this inside a transaction easily if it writes to another collection not involved in reading.
       // However, Firestore transactions require all reads before writes. 
       // We can just trigger it after transaction or assume "fire and forget" if using a separate service method outside transaction scope.
       // But to be safe, we will just use the Service's method which does a simple .add(), which is a write. 
       // Transactions are for atomic updates. Mixing simple adds might be okay if we don't need it to be atomic with this transaction.
       // Better approach: Do it AFTER transaction succeeds. We can't do that easily inside this private method unless we return data.
       
       // actually, let's just write to the notifications collection inside the transaction or use the service AFTER.
       // Since this method returns Void, we can't chain easily.
       // Let's modify the service to allow 'fire and forget' logging that doesn't block.
    });
    
    // FETCH notification details again to log it properly (since we need patientId etc which we had inside transaction)
    // Optimization: Pass the data out or just read it.
    // Given the complexity of transaction refactoring, we'll do a simple fire-and-forget logs 
    // by using a specialized method in NotificationService that takes the ID and checks it, 
    // OR just pass the known data here.

    // Let's assume the transaction succeeded.
    // We need to fetch the document again or use the variables we had. 
    // We can't access 'data' here. 
    // Let's refactor slightly to get data before transaction? No, need atomic read.
    
    // Simplest solution for Demo: Just read the doc after update and log.
    try {
      final updatedDoc = await _appointmentsRef.doc(appointmentId).get();
      if (updatedDoc.exists) {
        final data = updatedDoc.data() as Map<String, dynamic>;
        final token = data['tokenNumber'];
        final patientId = data['patientId'];
        final doctor = data['doctorName'];
        final time = (data['appointmentDate'] as Timestamp).toDate();
        
        final department = data['department'] ?? '';

        // 1. Token Assigned Notification
        NotificationService().logNotificationToDb(
          userId: patientId,
          notificationType: 'token_alert', // Strict string
          title: 'Appointment Approved',
          message: 'Your appointment with $doctor is approved. Your Token Number is $token.',
          relatedToken: token.toString(),
          scheduledTime: DateTime.now(),
          appointmentId: appointmentId,
          doctorName: doctor,
          department: department,
        );

        // 2. Appointment Reminder
        NotificationService().logNotificationToDb(
           userId: patientId,
           notificationType: 'appointment_reminder',
           title: 'Appointment Reminder',
           message: 'Reminder: Appointment with $doctor at $time. Token: $token',
           scheduledTime: time.subtract(const Duration(hours: 1)), // 1 hour before
           status: 'pending',
           appointmentId: appointmentId,
           doctorName: doctor,
           department: department, 
        );
      }
    } catch (e) {
       print("Error logging notification: $e");
    }
  }

  /// Completes the current appointment and automatically calls the next one.
  Future<void> completeCurrentAndCallNext(AppointmentModel current) async {
    final dateString = "${current.appointmentDate.year}-${current.appointmentDate.month.toString().padLeft(2, '0')}-${current.appointmentDate.day.toString().padLeft(2, '0')}";
    
    await _firestore.runTransaction((transaction) async {
      // 1. Mark current as completed
      transaction.update(_appointmentsRef.doc(current.id), {'status': AppointmentStatus.completed.name});
      
      // 2. Find next APPROVED token for this Doctor + Date
      final nextQuery = await _appointmentsRef
          .where('dateString', isEqualTo: dateString)
          .where('doctorName', isEqualTo: current.doctorName)
          .where('status', isEqualTo: AppointmentStatus.approved.name)
          .orderBy('tokenNumber', descending: false)
          .limit(1)
          .get(); 
          
      if (nextQuery.docs.isNotEmpty) {
          final nextDoc = nextQuery.docs.first;
          transaction.update(nextDoc.reference, {'status': AppointmentStatus.serving.name});
      }
    });
  }

  /// Skips the current appointment and automatically calls the next one.
  Future<void> skipCurrentAndCallNext(AppointmentModel current) async {
    final dateString = "${current.appointmentDate.year}-${current.appointmentDate.month.toString().padLeft(2, '0')}-${current.appointmentDate.day.toString().padLeft(2, '0')}";
    
    await _firestore.runTransaction((transaction) async {
      // 1. Mark current as skipped
      transaction.update(_appointmentsRef.doc(current.id), {'status': AppointmentStatus.skipped.name});
      
      final nextQuery = await _appointmentsRef
          .where('dateString', isEqualTo: dateString)
          .where('doctorName', isEqualTo: current.doctorName)
          .where('status', isEqualTo: AppointmentStatus.approved.name)
          .orderBy('tokenNumber', descending: false)
          .limit(1)
          .get(); 
          
      if (nextQuery.docs.isNotEmpty) {
          final nextDoc = nextQuery.docs.first;
          transaction.update(nextDoc.reference, {'status': AppointmentStatus.serving.name});
      }
    });
  }

  CollectionReference get _liveQueueRef => _firestore.collection('live_queues');

  /// Stream of the simplified Live Queue State (Single Source of Truth)
  Stream<Map<String, dynamic>> getLiveQueueState(String doctorName, DateTime date) {
    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final docId = "${dateString}_${doctorName.replaceAll(RegExp(r'\s+'), '_')}";
    
    return _liveQueueRef.doc(docId).snapshots().map((doc) {
       if (!doc.exists) return {'currentToken': 0, 'nextToken': 0};
       return doc.data() as Map<String, dynamic>;
    });
  }

  /// Helper to update the Live Queue State doc
  Future<void> _updateQueueState(String doctorName, DateTime date, int currentToken, int nextToken) async {
    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final docId = "${dateString}_${doctorName.replaceAll(RegExp(r'\s+'), '_')}";
    
    await _liveQueueRef.doc(docId).set({
      'currentToken': currentToken,
      'nextToken': nextToken,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Manually increments the token number (Staff Only) - UPDATED
  Future<void> incrementToken(String doctorName, DateTime date) async {
    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final doctorKey = doctorName.replaceAll(RegExp(r'\s+'), '_');
    final docId = "${dateString}_$doctorKey";

    try {
      final doc = await _liveQueueRef.doc(docId).get();
      int current = 0;
      if (doc.exists) {
        current = (doc.data() as Map<String, dynamic>)['currentToken'] ?? 0;
      }
      
      await jumpToToken(doctorName, date, current + 1);
    } catch (e) {
      print("Error incrementing token: $e");
      rethrow;
    }
  }

  /// Manually decrements the token number (Staff Only)
  Future<void> decrementToken(String doctorName, DateTime date) async {
      // Get current state first
      final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final doctorKey = doctorName.replaceAll(RegExp(r'\s+'), '_');
      final docId = "${dateString}_$doctorKey";
      
      final doc = await _liveQueueRef.doc(docId).get();
      if (!doc.exists) return;
      
      final current = (doc.data() as Map<String, dynamic>)['currentToken'] ?? 0;
      if (current > 1) { // Prevent going below 1
        await jumpToToken(doctorName, date, current - 1);
      } else if (current == 1) {
         // If 1, maybe go to 0? Requirements say "never go below 1". 
         // But purely for resetting, 0 might be needed. 
         // User said "ensure validation to prevent negative token values" and "token numbers never go below 1".
         // So I will stop at 1. Wait, if I want to "reset", maybe 0?
         // User said "never go below 1". Okay.
      }
  }

  /// Sets the current serving token directly (Staff Only) - UPDATED
  Future<void> jumpToToken(String doctorName, DateTime date, int targetToken) async {
    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final batch = _firestore.batch();
    
    try {
      final query = await _appointmentsRef
          .where('dateString', isEqualTo: dateString)
          .where('doctorName', isEqualTo: doctorName)
          .get(); // Fetch ALL for safety to avoid index issues
      
      final allDocs = query.docs;
      
      // Logic: 
      // < Target -> Completed
      // == Target -> Serving
      // > Target -> Approved
      
      for (var doc in allDocs) {
         final data = doc.data() as Map<String, dynamic>;
         final tNum = data['tokenNumber'] as int;
         final currentStatusName = data['status'];
         if (currentStatusName == AppointmentStatus.cancelled.name) continue;

         String newStatus = currentStatusName;

         if (tNum < targetToken) {
            if (newStatus != AppointmentStatus.completed.name && newStatus != AppointmentStatus.skipped.name) {
               newStatus = AppointmentStatus.completed.name;
            }
         } else if (tNum == targetToken) {
            newStatus = AppointmentStatus.serving.name;
         } else {
            // Future tokens
            if (newStatus == AppointmentStatus.serving.name || newStatus == AppointmentStatus.completed.name) {
               newStatus = AppointmentStatus.approved.name;
            }
         }

         if (newStatus != currentStatusName) {
            batch.update(doc.reference, {'status': newStatus});
         }
      }

      await batch.commit();
      
      // Calculate Next logic for Display
      // Find smallest token > targetToken that is NOT cancelled
      final potentialNext = allDocs.where((doc) {
         final d = doc.data() as Map<String, dynamic>;
         return (d['tokenNumber'] as int) > targetToken && d['status'] != AppointmentStatus.cancelled.name;
      }).toList();
      potentialNext.sort((a,b) => (a.data() as Map)['tokenNumber'].compareTo((b.data() as Map)['tokenNumber']));
      
      int nextTokenDisplay = potentialNext.isNotEmpty 
          ? (potentialNext.first.data() as Map<String, dynamic>)['tokenNumber'] as int
          : (targetToken + 1);

      // UPDATE SINGLE SOURCE OF TRUTH
      await _updateQueueState(doctorName, date, targetToken, nextTokenDisplay);

    } catch (e) {
       print("Error jumping token: $e");
       rethrow;
    }
  }

  /// Get pending appointments for Staff
  Stream<List<AppointmentModel>> getPendingAppointments() {
    return _appointmentsRef
        .where('status', isEqualTo: 'pending') // Explicitly String 'pending' to match enum.name
        // .orderBy('appointmentDate', descending: false) // REMOVED to avoid Composite Index requirement
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => AppointmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          
          // Sort client-side instead
          docs.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
          return docs;
        });
  }

  /// Get Pending, Approved, and Rejected appointments for Staff
  Stream<List<AppointmentModel>> getStaffAppointments() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    // STRICT RULE: Show ALL statuses for clarity
    return _appointmentsRef
        .where('status', whereIn: ['pending', 'approved', 'serving', 'rejected']) 
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => AppointmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .where((doc) {
                 // Filter out past appointments (Expiry logic)
                 final aptDay = DateTime(doc.appointmentDate.year, doc.appointmentDate.month, doc.appointmentDate.day);
                 return !aptDay.isBefore(today);
              })
              .toList();
          
          // Sort: Pending first (Action needed), then Approved/Serving (Active), then Rejected (History)
          docs.sort((a, b) {
             // 1. Pending always on top
             if (a.status == AppointmentStatus.pending && b.status != AppointmentStatus.pending) return -1;
             if (a.status != AppointmentStatus.pending && b.status == AppointmentStatus.pending) return 1;
             
             // 2. Approved/Serving second
             bool aActive = a.status == AppointmentStatus.approved || a.status == AppointmentStatus.serving;
             bool bActive = b.status == AppointmentStatus.approved || b.status == AppointmentStatus.serving;
             if (aActive && !bActive) return -1;
             if (!aActive && bActive) return 1;

             // 3. Statuses match (or both rejected), sort by date/time
             return a.appointmentDate.compareTo(b.appointmentDate);
          });
          return docs;
        });
  }
  /// Marks the token alert as triggered for a specific appointment
  Future<void> markAlertTriggered(String appointmentId) async {
    try {
      await _appointmentsRef.doc(appointmentId).update({'alertTriggered': true});
    } catch (e) {
      print("Error marking alert as triggered: $e");
    }
  }
}
