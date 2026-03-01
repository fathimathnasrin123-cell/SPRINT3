import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/volunteer_request_model.dart';
import '../models/caretaker_booking_model.dart';
import 'package:intl/intl.dart';
import '../../../core/services/notification_service.dart';

class StaffServicesScreen extends StatefulWidget {
  const StaffServicesScreen({super.key});

  @override
  State<StaffServicesScreen> createState() => _StaffServicesScreenState();
}

class _StaffServicesScreenState extends State<StaffServicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<QuerySnapshot> _volunteerRequestsStream;
  late Stream<QuerySnapshot> _caretakerBookingsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _volunteerRequestsStream = FirebaseFirestore.instance
        .collection('volunteer_requests')
        .orderBy('requestTime', descending: true)
        .snapshots();
    _caretakerBookingsStream = FirebaseFirestore.instance
        .collection('caretaker_bookings')
        .orderBy('requestTime', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Service Requests"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Volunteer Requests"),
            Tab(text: "Caretaker Bookings"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _VolunteerRequestsList(stream: _volunteerRequestsStream),
          _CaretakerBookingsList(stream: _caretakerBookingsStream),
        ],
      ),
    );
  }
}

class _VolunteerRequestsList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  const _VolunteerRequestsList({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text("No requests."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final req = VolunteerRequestModel.fromMap(data, docs[index].id);
            return Card(
              margin: const EdgeInsets.all(8),
              child: ExpansionTile(
                title: Text("${req.serviceType} - ${req.userName}"),
                subtitle: Text("Status: ${req.status}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("User ID: ${req.userId}"),
                        Text("Time: ${DateFormat('yyyy-MM-dd HH:mm').format(req.requestTime.toDate())}"),
                        const SizedBox(height: 10),
                        if (req.status == 'Pending')
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _updateStatus(context, req.id, 'volunteer_requests', 'Approved', req.userId),
                                child: const Text("Approve & Assign"),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _updateStatus(context, req.id, 'volunteer_requests', 'Rejected', req.userId),
                                child: const Text("Reject"),
                              ),
                            ],
                          ),
                         if (req.status == 'Approved')
                           ElevatedButton(
                             onPressed: () => _updateStatus(context, req.id, 'volunteer_requests', 'Completed', req.userId),
                             child: const Text("Mark as Completed"),
                           ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateStatus(BuildContext context, String id, String collection, String status, String userId) {
    if (status == 'Approved') {
       showDialog(context: context, builder: (ctx) {
         final controller = TextEditingController();
         return AlertDialog(
           title: const Text("Assign Volunteer"),
           content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Volunteer Name")),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
             ElevatedButton(onPressed: () {
                FirebaseFirestore.instance.collection(collection).doc(id).update({
                  'status': status,
                  'assignedVolunteerName': controller.text,
                  'assignedVolunteerContact': '123-456-7890',
                });
                
                NotificationService().logNotificationToDb(
                  userId: userId,
                  title: "Volunteer Service Approved",
                  message: "Your request for volunteer has been approved. Assigned: ${controller.text}",
                  notificationType: "service_update"
                );

                Navigator.pop(ctx);
             }, child: const Text("Assign"))
           ],
         );
       });
    } else {
       FirebaseFirestore.instance.collection(collection).doc(id).update({'status': status});
       
       String title = "Service Update";
       String message = "Your volunteer request status is now: $status";
       if (status == 'Rejected') {
          message = "Your volunteer request was rejected.";
       } else if (status == 'Completed') {
          message = "Your volunteer service has been marked as completed.";
       }

       NotificationService().logNotificationToDb(
          userId: userId,
          title: title,
          message: message,
          notificationType: "service_update"
       );
    }
  }
}

class _CaretakerBookingsList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  const _CaretakerBookingsList({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text("No bookings."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final booking = CaretakerBookingModel.fromMap(data, docs[index].id);
            return Card(
              margin: const EdgeInsets.all(8),
              child: ExpansionTile(
                title: Text("${booking.serviceType} - ${booking.userName}"),
                subtitle: Text("Status: ${booking.status}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Duration: ${booking.durationType}"),
                        Text("Time: ${DateFormat('yyyy-MM-dd HH:mm').format(booking.requestTime.toDate())}"),
                        const SizedBox(height: 10),
                        if (booking.status == 'Pending')
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _updateStatus(context, booking.id, 'caretaker_bookings', 'Confirmed', booking.userId),
                                child: const Text("Confirm & Assign"),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _updateStatus(context, booking.id, 'caretaker_bookings', 'Cancelled', booking.userId),
                                child: const Text("Reject"),
                              ),
                            ],
                          ),
                         if (booking.status == 'Confirmed')
                           ElevatedButton(
                             onPressed: () => _updateStatus(context, booking.id, 'caretaker_bookings', 'Completed', booking.userId),
                             child: const Text("Mark as Completed"),
                           ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateStatus(BuildContext context, String id, String collection, String status, String userId) {
     if (status == 'Confirmed') {
       showDialog(context: context, builder: (ctx) {
         final controller = TextEditingController();
         return AlertDialog(
           title: const Text("Assign Caretaker"),
           content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Caretaker Name")),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
             ElevatedButton(onPressed: () {
                FirebaseFirestore.instance.collection(collection).doc(id).update({
                  'status': status,
                  'assignedCaretakerName': controller.text,
                  'assignedCaretakerContact': '987-654-3210',
                });
                
                NotificationService().logNotificationToDb(
                  userId: userId,
                  title: "Caretaker Booking Confirmed",
                  message: "Your caretaker booking has been confirmed. Assigned: ${controller.text}",
                  notificationType: "service_update"
                );

                Navigator.pop(ctx);
             }, child: const Text("Assign"))
           ],
         );
       });
    } else {
       FirebaseFirestore.instance.collection(collection).doc(id).update({'status': status});
       
       String title = "Service Update";
       String message = "Your caretaker booking status is now: $status";
       if (status == 'Cancelled') {
          message = "Your caretaker booking was cancelled.";
       } else if (status == 'Completed') {
          message = "Your caretaker service has been marked as completed.";
       }

       NotificationService().logNotificationToDb(
          userId: userId,
          title: title,
          message: message,
          notificationType: "service_update"
       );
    }
  }
}
