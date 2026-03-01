import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../auth/services/auth_provider.dart';
import '../../models/volunteer_request_model.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/notification_service.dart';
import '../../../orders/services/order_history_service.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';


class VolunteerTaskDashboard extends StatefulWidget {
  const VolunteerTaskDashboard({super.key});

  @override
  State<VolunteerTaskDashboard> createState() => _VolunteerTaskDashboardState();
}

class _VolunteerTaskDashboardState extends State<VolunteerTaskDashboard> {
  late Stream<QuerySnapshot> _tasksStream;
  bool _isLocationEnabled = true;
  Timer? _locationTimer;
  StreamSubscription? _newRequestsSub;
  bool _isFirstLoad = true;


  @override
  void initState() {
    super.initState();
    _tasksStream = FirebaseFirestore.instance.collection('volunteer_requests')
            .where('status', whereIn: ['Pending', 'Accepted', 'Approved', 'On the Way']) 
            .snapshots();

    _newRequestsSub = FirebaseFirestore.instance.collection('volunteer_requests')
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
                final serviceType = data['serviceType'] ?? 'Unknown Task';
                final userName = data['userName'] ?? 'Someone';
                
                final String reqTime = data['requestTime'] != null 
                    ? DateFormat('h:mm a').format((data['requestTime'] as Timestamp).toDate()) 
                    : 'Now';

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("🚨 New Volunteer Request!", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.yellow)),
                        const SizedBox(height: 4),
                        Text("$userName needs help with $serviceType."),
                        Text("Time: $reqTime"),
                        if (data['location'] != null)
                           Text("Location: ${data['location']}", maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    backgroundColor: Colors.teal.shade800,
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
    _newRequestsSub?.cancel();
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
    final user = Provider.of<AuthProvider>(context).currentUser;
    final currentUserId = user?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F7), // Soft teal-ish background
      appBar: AppBar(
        title: const Text("Available Volunteer Requests"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
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
                      isAvailable ? "🟢 Available" : "🔴 Not Available",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: isAvailable,
                      onChanged: (val) => _toggleAvailability(val, currentUserId),
                      activeColor: Colors.white,
                      activeTrackColor: Colors.teal.shade300,
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
                  TextButton(onPressed: _checkLocationAndSync, child: const Text("Retry", style: TextStyle(color: Colors.teal)))
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
        stream: _tasksStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return const Center(child: Padding(
               padding: EdgeInsets.all(20),
               child: Text("Preparing shared tasks...", style: TextStyle(color: Colors.grey)),
             ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }
          
          final docsList = snapshot.data?.docs ?? [];
          final docs = docsList.toList();
          
          // Client-side sort to avoid index errors
          docs.sort((a, b) {
            final tA = (a.data() as Map<String, dynamic>)['requestTime'] as Timestamp;
            final tB = (b.data() as Map<String, dynamic>)['requestTime'] as Timestamp;
            return tB.compareTo(tA);
          });

          if (docs.isEmpty) {
             return const Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.volunteer_activism_outlined, size: 80, color: Colors.teal),
                   SizedBox(height: 16),
                   Text("No requests available at the moment.", style: TextStyle(fontSize: 18, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                 ],
               ),
             );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final req = VolunteerRequestModel.fromMap(data, docs[index].id);

              if ((req.status == 'Accepted' || req.status == 'Approved' || req.status == 'On the Way') && req.assignedVolunteerId != null && req.assignedVolunteerId != currentUserId) {
                 return const SizedBox.shrink(); 
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.teal.shade50,
                            child: const Icon(Icons.person, color: Colors.teal, size: 30),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(req.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Text(req.serviceType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal)),
                                ),
                              ],
                            ),
                          ),
                          Text(req.status, style: TextStyle(color: req.status == 'Pending' ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      _infoRow(Icons.location_on_outlined, req.location ?? "No location specified"),
                      const SizedBox(height: 8),
                      _infoRow(Icons.calendar_today_outlined, DateFormat('MMM d, yyyy • h:mm a').format(req.requestTime.toDate())),
                      const SizedBox(height: 12),
                      const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      Text(req.description ?? "No details provided.", style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 20),
                      
                      if (req.status == 'Pending')
                        Row(
                          children: [
                            Expanded(child: _actionButton("Accept Request", Colors.teal, () => _acceptTask(context, req, user?.name, user?.id, user?.contactNumber))),
                            const SizedBox(width: 8),
                            Expanded(child: _actionButton("Reject Request", Colors.redAccent, () => _rejectTask(context, req))),
                          ],
                        )
                      else if (req.status == 'On the Way' && req.assignedVolunteerId == currentUserId)
                         SizedBox(width: double.infinity, child: _actionButton("Mark as Completed", Colors.blue, () => _completeTask(context, req)))
                      else if ((req.status == 'Accepted' || req.status == 'Approved') && req.assignedVolunteerId == currentUserId)
                         const SizedBox(
                           width: double.infinity, 
                           child: Padding(
                             padding: EdgeInsets.symmetric(vertical: 8.0),
                             child: Text("Task accepted. Preparing task... please wait.", textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                           )
                         ),
                      
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _viewDetails(req), child: const Text("View Details"))),
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

  Widget _infoRow(IconData icon, String text) {
    bool isUrl = text.startsWith('http');
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: isUrl 
            ? InkWell(
                onTap: () async {
                  final uri = Uri.parse(text);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, webOnlyWindowName: '_blank');
                  }
                },
                child: Text(
                  text, 
                  style: const TextStyle(color: Colors.blue, fontSize: 14, decoration: TextDecoration.underline),
                ),
              )
            : Text(text, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _viewDetails(VolunteerRequestModel req) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(req.serviceType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("From: ${req.userName}"),
            Text("Location: ${req.location ?? 'N/A'}"),
            Text("Time: ${DateFormat('MMM d, h:mm a').format(req.requestTime.toDate())}"),
            const SizedBox(height: 12),
            const Text("Notes:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(req.description ?? "No additional notes."),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Future<void> _acceptTask(BuildContext context, VolunteerRequestModel req, String? volunteerName, String? volunteerId, String? contactNumber) async {
     if (volunteerId == null) return;
     try {
       await FirebaseFirestore.instance.collection('volunteer_requests').doc(req.id).update({
         'status': 'Accepted',
         'assignedVolunteerName': volunteerName ?? 'Volunteer',
         'assignedVolunteerId': volunteerId,
         'assignedVolunteerContact': contactNumber ?? 'Not provided', 
       });
       await OrderHistoryService().recordStateChange(
         orderId: req.id,
         previousState: req.status,
         newState: 'Accepted',
         customerId: req.userId,
         remarks: 'Accepted by ${volunteerName ?? 'Volunteer'}',
       );
       await NotificationService().logNotificationToDb(
          userId: req.userId,
          title: "Volunteer Accepted",
          message: "${volunteerName ?? 'A volunteer'} has accepted your request for ${req.serviceType}.",
          notificationType: "service_update"
       );
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task Accepted! Status will automatically update to 'On the Way' shortly.")));
       
       Future.delayed(const Duration(seconds: 12), () async {
         try {
           final docSnapshot = await FirebaseFirestore.instance.collection('volunteer_requests').doc(req.id).get();
           if (docSnapshot.exists && docSnapshot.data()?['status'] == 'Accepted') {
               await FirebaseFirestore.instance.collection('volunteer_requests').doc(req.id).update({'status': 'On the Way'});
                await OrderHistoryService().recordStateChange(
                  orderId: req.id,
                  previousState: 'Accepted',
                  newState: 'On the Way',
                  customerId: req.userId,
                );
               await NotificationService().logNotificationToDb(
                  userId: req.userId,
                  title: "Volunteer On the Way",
                  message: "${volunteerName ?? 'A volunteer'} is now on the way for your ${req.serviceType} task.",
                  notificationType: "service_update"
               );
           }
         } catch (e) {
           debugPrint("Failed to update status to On the Way: $e");
         }
       });
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
     }
  }

  Future<void> _rejectTask(BuildContext context, VolunteerRequestModel req) async {
     final reasonController = TextEditingController();
     final shouldReject = await showDialog<bool>(
       context: context, 
       builder: (ctx) => AlertDialog(
         title: const Text("Reject Task"),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text("Reason for rejection (optional):"),
             const SizedBox(height: 8),
             TextField(controller: reasonController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Enter reason or leave blank")),
           ],
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
           ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Submit")),
         ],
       )
     );

     if (shouldReject != true) return;
     try {
       await FirebaseFirestore.instance.collection('volunteer_requests').doc(req.id).update({
         'status': 'Rejected',
         'rejectionReason': reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
       });
       await OrderHistoryService().recordStateChange(
         orderId: req.id,
         previousState: req.status,
         newState: 'Rejected',
         customerId: req.userId,
         remarks: reasonController.text.trim(),
       );
       await NotificationService().logNotificationToDb(
          userId: req.userId,
          title: "Request Rejected",
          message: "A volunteer was unable to accept your request.",
          notificationType: "service_update"
       );
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rejected")));
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
     }
  }

  Future<void> _completeTask(BuildContext context, VolunteerRequestModel req) async {
     try {
       await FirebaseFirestore.instance.collection('volunteer_requests').doc(req.id).update({'status': 'Completed'});
       await OrderHistoryService().recordStateChange(
         orderId: req.id,
         previousState: req.status,
         newState: 'Completed',
         customerId: req.userId,
       );
       await NotificationService().logNotificationToDb(
          userId: req.userId,
          title: "Service Completed",
          message: "Your volunteer request for ${req.serviceType} has been completed.",
          notificationType: "service_update"
       );
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Task Completed!")));
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
     }
  }
}
