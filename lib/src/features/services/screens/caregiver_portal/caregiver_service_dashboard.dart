import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../auth/services/auth_provider.dart';
import '../../models/caretaker_booking_model.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/notification_service.dart';
import '../../../orders/services/order_history_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';


class CaregiverServiceDashboard extends StatefulWidget {
  const CaregiverServiceDashboard({super.key});

  @override
  State<CaregiverServiceDashboard> createState() => _CaregiverServiceDashboardState();
}

class _CaregiverServiceDashboardState extends State<CaregiverServiceDashboard> {
  late Stream<QuerySnapshot> _bookingsStream;
  bool _isLocationEnabled = true;
  Timer? _locationTimer;
  StreamSubscription? _newBookingsSub;
  bool _isFirstLoad = true;


  @override
  void initState() {
    super.initState();
    _bookingsStream = FirebaseFirestore.instance.collection('caretaker_bookings')
            .where('status', whereIn: ['Pending', 'Confirmed'])
            .snapshots();

    _newBookingsSub = FirebaseFirestore.instance.collection('caretaker_bookings')
            .where('status', isEqualTo: 'Pending')
            .snapshots().listen((snapshot) {
       if (_isFirstLoad) {
          _isFirstLoad = false;
          return;
       }
       for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
             final data = change.doc.data();
             if (data != null && mounted) {
                final serviceType = data['serviceType'] ?? 'Unknown Service';
                final userName = data['userName'] ?? 'A patient';
                
                final String reqTime = data['bookingTime'] != null 
                    ? DateFormat('h:mm a').format((data['bookingTime'] as Timestamp).toDate()) 
                    : 'Now';

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("🚨 New Caregiver Request!", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.yellow)),
                        const SizedBox(height: 4),
                        Text("$userName requested $serviceType."),
                        Text("Time: $reqTime"),
                        if (data['location'] != null)
                           Text("Location: ${data['location']}", maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    backgroundColor: Colors.indigo.shade800,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 6),
                  )
                );
             }
          }
       }
    });

    _checkLocationAndSync();
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) => _checkLocationAndSync());
  }

  @override
  void dispose() {
    _newBookingsSub?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationAndSync() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLocationEnabled = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocationEnabled = false);
        return;
      }
    } else if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLocationEnabled = false);
      return;
    }

    if (mounted) setState(() => _isLocationEnabled = true);
    
    // Attempt to get location and update user periodically
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      String areaDetails = '';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          areaDetails = [place.street, place.subLocality, place.locality, place.administrativeArea]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
        }
      } catch (e) {
        debugPrint("Geocoding failed: $e");
      }

      await FirebaseFirestore.instance.collection('users').doc(user.id).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'areaDetails': areaDetails,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  Future<void> _toggleAvailability(bool value, String userId) async {
    if (value && !_isLocationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enable location to receive service requests."))
      );
      _checkLocationAndSync();
      return;
    }
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAvailable': value,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update status")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current user is the caregiver
    final user = Provider.of<AuthProvider>(context).currentUser;
    final currentUserId = user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Service Requests"),
        actions: [
          if (currentUserId != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final bool isAvailable = userData['isAvailable'] ?? false;
                
                return Row(
                  children: [
                    Text(
                      isAvailable ? "🟢 Available" : "🔴 Unavailable",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isAvailable ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                    Switch(
                      value: isAvailable,
                      onChanged: (val) => _toggleAvailability(val, currentUserId),
                      activeColor: Colors.green,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isLocationEnabled)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade100,
              width: double.infinity,
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(child: Text("Please enable location to receive service requests.", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))),
                  TextButton(onPressed: _checkLocationAndSync, child: const Text("Retry"))
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
        stream: _bookingsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return const Center(child: Padding(
               padding: EdgeInsets.all(20),
               child: Text("Preparing service requests...", style: TextStyle(color: Colors.grey)),
             ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(child: Text("No bookings available."));
          }

          final docs = snapshot.data!.docs.toList();

          // Client-side sort to avoid index errors
          docs.sort((a, b) {
            final tA = (a.data() as Map<String, dynamic>)['requestTime'] as Timestamp;
            final tB = (b.data() as Map<String, dynamic>)['requestTime'] as Timestamp;
            return tB.compareTo(tA);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final booking = CaretakerBookingModel.fromMap(data, docs[index].id);

              // 1. If assigned to someone else -> Hide
              if (booking.status == 'Confirmed' && booking.assignedCaretakerId != null && booking.assignedCaretakerId != currentUserId) {
                 return const SizedBox.shrink();
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                           child: Text(
                             "ID: ${booking.uniqueId.isNotEmpty ? booking.uniqueId : booking.userId}", 
                             style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           "User: ${booking.userName}", 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                         ),
                         Text(
                           "Service: ${booking.serviceType}", 
                           style: const TextStyle(fontSize: 14, color: Colors.blueGrey)
                         ),
                         if (booking.location != null && booking.location!.isNotEmpty) ...[
                           const SizedBox(height: 4),
                           if (booking.location!.startsWith('http'))
                             InkWell(
                               onTap: () async {
                                 final uri = Uri.parse(booking.location!);
                                 if (await canLaunchUrl(uri)) {
                                   await launchUrl(uri, webOnlyWindowName: '_blank');
                                 }
                               },
                               child: Text(
                                 "Location: ${booking.location}",
                                 style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline),
                               ),
                             )
                           else
                             Text("Location: ${booking.location}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                         ],
                       Text("Time: ${DateFormat('h:mm a, dd MMM').format(booking.requestTime.toDate())}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                       const SizedBox(height: 8),
                       Text("Status: ${booking.status}", style: TextStyle(
                         color: booking.status == 'Pending' ? Colors.orange : (booking.status == 'Confirmed' ? Colors.green : Colors.black),
                         fontWeight: FontWeight.bold,
                         fontSize: 12
                       )),
                       if (booking.status == 'Confirmed')
                         Text("Helper: ${booking.assignedCaretakerName ?? 'Me'}", style: const TextStyle(fontSize: 12)),
                       
                       const SizedBox(height: 12),
                       // ACTIONS
                       if (booking.status == 'Pending')
                         Row(
                           children: [
                             Expanded(
                               child: ElevatedButton(
                                 onPressed: () => _acceptBooking(context, booking, user?.name, user?.id, user?.contactNumber),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.green, 
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(vertical: 8),
                                   minimumSize: const Size(0, 36)
                                 ),
                                 child: const Text("Approve"),
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: ElevatedButton(
                                 onPressed: () => _rejectBooking(context, booking),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.red, 
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(vertical: 8),
                                   minimumSize: const Size(0, 36)
                                 ),
                                 child: const Text("Reject"),
                               ),
                             ),
                           ],
                         )
                       else if (booking.status == 'Confirmed' && booking.assignedCaretakerId == currentUserId)
                         SizedBox(
                           width: double.infinity,
                           child: ElevatedButton(
                             onPressed: () => _completeBooking(context, booking),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.blue, 
                               foregroundColor: Colors.white,
                               padding: const EdgeInsets.symmetric(vertical: 8),
                               minimumSize: const Size(0, 36)
                             ),
                             child: const Text("Mark Completed"),
                           ),
                         ),
                    ],
                  ),
                ),
              );
            },
          );
         },
       ),
      ),
     ],
    ),
   );
  }

  Future<void> _acceptBooking(BuildContext context, CaretakerBookingModel booking, String? caregiverName, String? caregiverId, String? contactNumber) async {
     if (caregiverId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: User not identified")));
       return;
     }

     try {
       await FirebaseFirestore.instance.collection('caretaker_bookings').doc(booking.id).update({
         'status': 'Confirmed', // Caregiver "Accepts" = Confirmed
         'assignedCaretakerName': caregiverName ?? 'Caregiver',
         'assignedCaretakerId': caregiverId,
         'assignedCaretakerContact': contactNumber ?? 'Not provided',
       });

       await OrderHistoryService().recordStateChange(
         orderId: booking.id,
         previousState: booking.status,
         newState: 'Confirmed',
         customerId: booking.userId,
         remarks: 'Accepted by ${caregiverName ?? 'Caregiver'}',
       );

       await NotificationService().logNotificationToDb(
          userId: booking.userId,
          title: "Booking Confirmed",
          message: "${caregiverName ?? 'A caregiver'} has accepted your booking for ${booking.serviceType}.",
          notificationType: "service_update"
       );

       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking Accepted!")));
       }
     } catch (e) {
       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to accept booking: $e")));
       }
     }
  }

  Future<void> _rejectBooking(BuildContext context, CaretakerBookingModel booking) async {
     final reasonController = TextEditingController();
     
     final shouldReject = await showDialog<bool>(
       context: context, 
       builder: (ctx) => AlertDialog(
         title: const Text("Reject Booking"),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text("Please provide a reason for rejecting this request:"),
             const SizedBox(height: 8),
             TextField(
               controller: reasonController,
               decoration: const InputDecoration(
                 hintText: "Reason (e.g., Busy, Out of coverage)",
                 border: OutlineInputBorder()
               ),
               maxLines: 3,
             )
           ],
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
           ElevatedButton(
             onPressed: () {
               if (reasonController.text.trim().isEmpty) {
                 ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Please enter a reason")));
                 return;
               }
               Navigator.pop(ctx, true);
             }, 
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
             child: const Text("Reject")
           ),
         ],
       )
     );

     if (shouldReject != true) return;

     try {
       await FirebaseFirestore.instance.collection('caretaker_bookings').doc(booking.id).update({
         'status': 'Rejected',
         'rejectionReason': reasonController.text.trim()
       });
       
       await OrderHistoryService().recordStateChange(
         orderId: booking.id,
         previousState: booking.status,
         newState: 'Rejected',
         customerId: booking.userId,
         remarks: 'Rejected: ${reasonController.text.trim()}',
       );
       
       await NotificationService().logNotificationToDb(
          userId: booking.userId,
          title: "Booking Rejected",
          message: "Caregiver declined: ${reasonController.text.trim()}",
          notificationType: "service_update"
       );

       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking Rejected")));
       }
     } catch (e) {
       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
     }
  }

  Future<void> _completeBooking(BuildContext context, CaretakerBookingModel booking) async {
     try {
       await FirebaseFirestore.instance.collection('caretaker_bookings').doc(booking.id).update({
         'status': 'Completed',
         'permissionStatus': 'Pending',
       });

       await OrderHistoryService().recordStateChange(
         orderId: booking.id,
         previousState: booking.status,
         newState: 'Completed',
         customerId: booking.userId,
       );

       await NotificationService().logNotificationToDb(
          userId: booking.userId,
          title: "Service Completed",
          message: "Your caretaker service for ${booking.serviceType} has been marked as completed.",
          notificationType: "service_update"
       );

       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking Completed!")));
       }
     } catch (e) {
       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
       }
     }
  }
}
