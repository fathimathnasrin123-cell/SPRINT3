import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/services/auth_provider.dart';
import '../models/caretaker_booking_model.dart';
import 'package:intl/intl.dart';
import '../../../core/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CaretakerServiceScreen extends StatefulWidget {
  const CaretakerServiceScreen({super.key});

  @override
  State<CaretakerServiceScreen> createState() => _CaretakerServiceScreenState();
}

class _CaretakerServiceScreenState extends State<CaretakerServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedService = 'Daily care';
  final List<String> _serviceTypes = ['Daily care', 'Medical assistance', 'Home support', 'Emergency help'];
  
  String _selectedDuration = 'Hourly';
  final List<String> _durationTypes = ['Hourly', 'Daily', 'Monthly'];
  
  final TextEditingController _contactController = TextEditingController();
  String? _locationUrl;
  Position? _currentPosition;
  bool _isLocationLoading = true;
  String _locationStatus = "Fetching live GPS location...";
  bool _permissionDenied = false;

  bool _isLoading = false;
  Stream<QuerySnapshot>? _bookingsStream;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _permissionDenied = false;
      _locationStatus = "Fetching live GPS location...";
    });

    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = "Location services are disabled.";
          _isLocationLoading = false;
          _permissionDenied = true;
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = "Location permission denied.";
            _isLocationLoading = false;
            _permissionDenied = true;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = "Location permissions are permanently denied.";
          _isLocationLoading = false;
          _permissionDenied = true;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _locationUrl = "https://www.google.com/maps?q=${position.latitude},${position.longitude}";
        _isLocationLoading = false;
      });
    } catch (e) {
      setState(() {
        _locationStatus = "Error fetching location: $e";
        _isLocationLoading = false;
        _permissionDenied = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user != null && user.id != _lastUserId) {
      _lastUserId = user.id;
      _bookingsStream = FirebaseFirestore.instance
          .collection('caretaker_bookings')
          .where('userId', isEqualTo: user.id)
          .snapshots();
    }
  }

  Future<void> _bookCaretaker() async {
    if (!_formKey.currentState!.validate()) return;
    if (_locationUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location access is required to continue.")));
      return;
    }

    String address = "Coordinates: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}";
    if (_currentPosition != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          address = [place.street, place.subLocality, place.locality, place.administrativeArea, place.postalCode]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
        }
      } catch (e) {
        debugPrint("Geocoding failed: $e");
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Request", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Please review your request before submitting:"),
              const SizedBox(height: 16),
              Text("Service:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
              Text("$_selectedService ($_selectedDuration)"),
              const SizedBox(height: 8),
              Text("Delivery Location:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
              Text(address),
              const SizedBox(height: 8),
              Text("Contact:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
              Text(_contactController.text),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Edit or Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            child: const Text("Confirm and Send Request"),
          ),
        ],
      )
    );

    if (confirmed != true) return;

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: User not found")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('caretaker_bookings').doc();
      final booking = CaretakerBookingModel(
        id: docRef.id,
        userId: user.id,
        uniqueId: user.uniqueId ?? '', 
        userName: user.name,
        serviceType: _selectedService,
        durationType: _selectedDuration,
        status: 'Pending',
        requestTime: Timestamp.now(),
        location: _locationUrl,
        contactDetails: _contactController.text.trim(),
      );

      await docRef.set(booking.toMap());

      try {
        final caregiversSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'caregiver').get();
        final caregiverIds = caregiversSnapshot.docs.map((doc) => doc.id).toList();
        if (caregiverIds.isNotEmpty) {
           await NotificationService().logNotificationToDb(
             title: "New Caregiver Request",
             message: "${user.name} requested $_selectedService.",
             notificationType: "new_request",
             targetUserIds: caregiverIds,
           );
        }
      } catch (e) {
        debugPrint("Error notifying caregivers: $e");
      }

      _contactController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caretaker booking requested!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePermission(CaretakerBookingModel booking, bool isAllowed) async {
    try {
      if (!isAllowed) {
        // Handle Deny
        await FirebaseFirestore.instance.collection('caretaker_bookings').doc(booking.id).update({
          'permissionStatus': 'Denied',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access denied. Account will not be linked.")));
        }
        return;
      }

      // Handle Allow -> Auto Linking
      if (booking.assignedCaretakerId == null || booking.userId.isEmpty) return;

      // Check current limit first
      final linksSnapshot = await FirebaseFirestore.instance
          .collection('linked_users')
          .doc(booking.assignedCaretakerId)
          .collection('elderlies')
          .get();

      if (linksSnapshot.docs.length >= 5) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caregiver has reached maximum linked accounts (5/5).")));
         }
         return;
      }

      // 1. Update Booking Status
      await FirebaseFirestore.instance.collection('caretaker_bookings').doc(booking.id).update({
        'permissionStatus': 'Approved',
      });

      // 2. Add to linked_users collection
      await FirebaseFirestore.instance
          .collection('linked_users')
          .doc(booking.assignedCaretakerId)
          .collection('elderlies')
          .doc(booking.userId)
          .set({
        'elderlyId': booking.userId,
        'linkedAt': FieldValue.serverTimestamp(),
        'linkedBy': 'auto',
      });

      // Also add to auth provider's linkedElderlyIds to maintain compatibility
      final caregiverDoc = await FirebaseFirestore.instance.collection('users').doc(booking.assignedCaretakerId).get();
      if (caregiverDoc.exists) {
        final links = List<String>.from((caregiverDoc.data() as Map<String, dynamic>)['linkedElderlyIds'] ?? []);
        if (!links.contains(booking.userId)) {
          links.add(booking.userId);
          await FirebaseFirestore.instance.collection('users').doc(booking.assignedCaretakerId).update({
            'linkedElderlyIds': links
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Allowed! Accounts successfully linked.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing request: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Caretaker Service")),
      body: SingleChildScrollView(
        child: Column(
          children: [
          // Booking Form
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.withOpacity(0.05),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Book Professional Caretaker", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedService,
                          items: _serviceTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 16)))).toList(),
                          onChanged: (val) => setState(() => _selectedService = val!),
                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Service Type"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDuration,
                          items: _durationTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 16)))).toList(),
                          onChanged: (val) => setState(() => _selectedDuration = val!),
                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Duration"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Location Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _permissionDenied ? Colors.red : Colors.indigo.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Current Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                        const SizedBox(height: 4),
                        if (_isLocationLoading)
                          const Row(
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo)),
                              SizedBox(width: 8),
                              Text("Capturing GPS coordinates...", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                          )
                        else if (_locationUrl != null)
                          Text(_locationUrl!, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)
                        else
                          Text(_locationStatus, style: const TextStyle(fontSize: 12, color: Colors.red)),
                        const SizedBox(height: 4),
                        const Text("Location is captured automatically using live GPS.", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        if (_permissionDenied)
                          TextButton.icon(
                            onPressed: _getCurrentLocation, 
                            icon: const Icon(Icons.refresh, size: 16, color: Colors.indigo), 
                            label: const Text("Retry Access", style: TextStyle(fontSize: 12, color: Colors.indigo))
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(), 
                      labelText: "Contact Number",
                      hintText: "Enter your 10-digit number",
                      prefixIcon: Icon(Icons.phone)
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Contact number is mandatory";
                      if (!RegExp(r'^\d{10}$').hasMatch(val)) return "Please enter a valid 10-digit number";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_permissionDenied && _locationUrl == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text("Please enable location access to continue.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                    ),
                  ElevatedButton(
                    onPressed: (_isLoading || _locationUrl == null) ? null : _bookCaretaker,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : const Text("Book Caretaker"),
                  )
                ],
              ),
            ),
          ),
          
          if (_currentPosition != null)
            _NearbyCaretakersPanel(currentPosition: _currentPosition!),

          StreamBuilder<QuerySnapshot>(
            stream: _bookingsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                   return const Center(child: Padding(
                     padding: EdgeInsets.all(20),
                     child: Text("Preparing your bookings...", style: TextStyle(color: Colors.grey)),
                   ));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = (snapshot.data?.docs ?? []).toList();
                docs.sort((a, b) {
                  final tA = (a.data() as Map<String, dynamic>)['requestTime'] as Timestamp;
                  final tB = (b.data() as Map<String, dynamic>)['requestTime'] as Timestamp;
                  return tB.compareTo(tA);
                });
                
                return ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.medical_services, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(_isLoading ? "Processing booking..." : "No bookings yet.", 
                                style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final booking = CaretakerBookingModel.fromMap(data, doc.id);
                      
                      Color statusColor = Colors.orange;
                      if (booking.status == 'Confirmed') statusColor = Colors.green;
                      if (booking.status == 'Completed') statusColor = Colors.blue;
                      if (booking.status == 'Cancelled' || booking.status == 'Rejected') statusColor = Colors.red;

                      return Card(
                        key: ValueKey(doc.id),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text("${booking.serviceType} (${booking.durationType})", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               subtitleWidget(booking), // we will define a separate piece here
                               Text("Status: ${booking.status}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                               if (booking.status == 'Confirmed' && booking.assignedCaretakerName != null) ...[
                                 const SizedBox(height: 4),
                                 Text("Caretaker: ${booking.assignedCaretakerName}"),
                                 Text("Contact: ${booking.assignedCaretakerContact ?? 'N/A'}"),
                               ],
                               if (booking.status == 'Rejected') ...[
                                 const SizedBox(height: 4),
                                 Container(
                                   padding: const EdgeInsets.all(8),
                                   decoration: BoxDecoration(
                                     color: Colors.red.shade50,
                                     borderRadius: BorderRadius.circular(8),
                                     border: Border.all(color: Colors.red.shade200),
                                   ),
                                   child: Row(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       const Icon(Icons.info_outline, color: Colors.red, size: 16),
                                       const SizedBox(width: 6),
                                       Expanded(
                                         child: Text(
                                           "Reason: ${booking.rejectionReason?.isNotEmpty == true ? booking.rejectionReason : 'Not specified'}",
                                           style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                               ]
                            ],
                          ),
                          trailing: Text(
                            DateFormat('MMM d, h:mm a').format(booking.requestTime.toDate()),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget subtitleWidget(CaretakerBookingModel booking) {
    if (booking.status == 'Completed' && booking.permissionStatus == 'Pending') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade400),
          borderRadius: BorderRadius.circular(8)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Allow Health Monitor Access", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 14)
            ),
            const SizedBox(height: 4),
            const Text(
              "The caregiver has completed your service request. If you allow access, your account will be linked and your health details will be visible to the caregiver.",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _handlePermission(booking, false),
                  child: const Text("Deny", style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handlePermission(booking, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text("Allow"),
                )
              ],
            )
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _NearbyCaretakersPanel extends StatelessWidget {
  final Position currentPosition;
  const _NearbyCaretakersPanel({required this.currentPosition});

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0; // km
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'caregiver')
        .where('isAvailable', isEqualTo: true)
        .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final caregivers = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        
        // Filter by distance
        final nearby = caregivers.where((c) {
          if (c['latitude'] == null || c['longitude'] == null) return false;
          final dist = _calculateDistance(currentPosition.latitude, currentPosition.longitude, c['latitude'], c['longitude']);
          return dist <= 15.0; // Within 15km radius
        }).toList();

        if (nearby.isEmpty) {
          return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text("No helpers available within 15 km of your location.", style: TextStyle(color: Colors.red, fontSize: 13, fontStyle: FontStyle.italic)),
          );
        }

        // Sort by nearest
        nearby.sort((a, b) {
          final dA = _calculateDistance(currentPosition.latitude, currentPosition.longitude, a['latitude'], a['longitude']);
          final dB = _calculateDistance(currentPosition.latitude, currentPosition.longitude, b['latitude'], b['longitude']);
          return dA.compareTo(dB);
        });

        return Container(
          height: 220,
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("Available Nearby Caregivers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: nearby.length,
                  itemBuilder: (context, index) {
                    final dist = _calculateDistance(currentPosition.latitude, currentPosition.longitude, nearby[index]['latitude'], nearby[index]['longitude']);
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Container(
                        decoration: BoxDecoration(
                          border: const Border(left: BorderSide(color: Colors.green, width: 4)),
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(12),
                        width: 150,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircleAvatar(radius: 20, backgroundColor: Colors.indigo, child: Icon(Icons.person, size: 24, color: Colors.white)),
                            const SizedBox(height: 8),
                            Flexible(
                              child: Text(
                                nearby[index]['name'] ?? 'Caregiver', 
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14), 
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                softWrap: true,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("${dist.toStringAsFixed(1)} km away", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("Available", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
