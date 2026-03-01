import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/services/auth_provider.dart';
import '../models/volunteer_request_model.dart';
import 'package:intl/intl.dart';
import '../../../core/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class VolunteerServiceScreen extends StatefulWidget {
  const VolunteerServiceScreen({super.key});

  @override
  State<VolunteerServiceScreen> createState() => _VolunteerServiceScreenState();
}

class _VolunteerServiceScreenState extends State<VolunteerServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedService = 'Medicine pickup';
  final List<String> _serviceTypes = ['Medicine pickup', 'Grocery Shopping', 'Daily errands'];
  
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  final List<String> _medicineExamples = ['Paracetamol', 'Insulin', 'BP Tablets', 'Vitamins', 'Cough Syrup', 'Painkillers'];
  final List<String> _groceryExamples = ['Rice', 'Vegetables', 'Milk', 'Bread', 'Soap', 'Toothpaste', 'Fruits', 'Eggs'];
  
  final Set<String> _selectedChips = {};
  final TextEditingController _specificItemsController = TextEditingController();

  
  String? _locationUrl;
  Position? _currentPosition;
  bool _isLocationLoading = true;
  String _locationStatus = "Fetching live GPS location...";
  bool _permissionDenied = false;

  bool _isLoading = false;
  Stream<QuerySnapshot>? _requestsStream;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _contactController.dispose();
    _descriptionController.dispose();
    _specificItemsController.dispose();
    super.dispose();
  }


  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _permissionDenied = false;
      _locationStatus = "Fetching live GPS location...";
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = "Location services are disabled.";
          _isLocationLoading = false;
          _permissionDenied = true;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
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
      _requestsStream = FirebaseFirestore.instance
          .collection('volunteer_requests')
          .where('userId', isEqualTo: user.id)
          .snapshots();
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_locationUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location access is required to continue.")));
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: User not found")));
      return;
    }

    String finalDescription = _descriptionController.text.trim();
    String details = "";
    if (_selectedService == 'Medicine pickup' || _selectedService == 'Grocery Shopping' || _selectedService == 'Daily errands') {
      if (_selectedChips.isNotEmpty) {
        details += "Selected Items: ${_selectedChips.join(', ')}\n";
      }
      if (_specificItemsController.text.trim().isNotEmpty) {
        details += "Specific Details: ${_specificItemsController.text.trim()}\n";
      }
    }

    if (details.isNotEmpty) {
      if (finalDescription.isNotEmpty) {
        finalDescription = "$details\nAdditional Notes:\n$finalDescription";
      } else {
        finalDescription = details.trim();
      }
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
              Text("Task:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
              Text(_selectedService),
              const SizedBox(height: 8),
              Text("Details:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
              Text(finalDescription.isEmpty ? "None" : finalDescription),
              const SizedBox(height: 8),
              Text("Delivery Location:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
              Text(address),
              const SizedBox(height: 8),
              Text("Contact:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text("Confirm and Send Request"),
          ),
        ],
      )
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('volunteer_requests').doc();
      final request = VolunteerRequestModel(
        id: docRef.id,
        userId: user.id,
        uniqueId: user.uniqueId ?? '',
        userName: user.name,
        serviceType: _selectedService,
        status: 'Pending',
        requestTime: Timestamp.now(),
        location: _locationUrl,
        description: finalDescription,
        contactDetails: _contactController.text.trim(),
      );

      await docRef.set(request.toMap());

      try {
        final volunteersSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'volunteer').get();
        final volunteerIds = volunteersSnapshot.docs.map((doc) => doc.id).toList();
        if (volunteerIds.isNotEmpty) {
           await NotificationService().logNotificationToDb(
             title: "New Volunteer Request",
             message: "${user.name} needs help with $_selectedService.",
             notificationType: "new_request",
             targetUserIds: volunteerIds,
           );
        }
      } catch (e) {
        debugPrint("Error notifying volunteers: $e");
      }

      _contactController.clear();
      _descriptionController.clear();
      _specificItemsController.clear();
      setState(() => _selectedChips.clear());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Volunteer request sent!")));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Volunteer Service")),
      body: SingleChildScrollView(
        child: Column(
          children: [
          // Request Form
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.withOpacity(0.05),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Request Assistance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedService,
                    items: _serviceTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 16)))).toList(),
                    onChanged: (val) {
                      if (val != _selectedService) {
                        setState(() {
                           _selectedService = val!;
                           _selectedChips.clear();
                           _specificItemsController.clear();
                        });
                      }
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Choose Service"),
                  ),
                  const SizedBox(height: 12),
                  
                  // Dynamic fields based on task type
                  if (_selectedService == 'Medicine pickup') ...[
                    const Text("Common Medicines (Select needed):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _medicineExamples.map((item) {
                        final isSelected = _selectedChips.contains(item);
                        return FilterChip(
                          label: Text(item),
                          selected: isSelected,
                          selectedColor: Colors.teal.shade200,
                          checkmarkColor: Colors.teal.shade900,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedChips.add(item);
                              } else {
                                _selectedChips.remove(item);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specificItemsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Exact Medicine Names / Dosage / Prescription Info",
                        hintText: "e.g., Dolo 650 1 strip, Amlodipine 5mg...",
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (_selectedService == 'Grocery Shopping' || _selectedService == 'Daily errands') ...[
                    const Text("Common Items (Select needed):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _groceryExamples.map((item) {
                        final isSelected = _selectedChips.contains(item);
                        return FilterChip(
                          label: Text(item),
                          selected: isSelected,
                          selectedColor: Colors.teal.shade200,
                          checkmarkColor: Colors.teal.shade900,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedChips.add(item);
                              } else {
                                _selectedChips.remove(item);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specificItemsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Specific Items & Quantities",
                        hintText: "e.g., 2 liters Milk, 1 loaf of wheat bread...",
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Location Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _permissionDenied ? Colors.red : Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Current Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
                        const SizedBox(height: 4),
                        if (_isLocationLoading)
                          const Row(
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal)),
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
                            icon: const Icon(Icons.refresh, size: 16, color: Colors.teal), 
                            label: const Text("Retry Access", style: TextStyle(fontSize: 12, color: Colors.teal))
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Request Description", hintText: "e.g. Need medicine from ABC clinic"),
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
                    onPressed: (_isLoading || _locationUrl == null) ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Request Volunteer"),
                  )
                ],
              ),
            ),
          ),
          
          if (_currentPosition != null)
            _NearbyVolunteersPanel(currentPosition: _currentPosition!),

          StreamBuilder<QuerySnapshot>(
            stream: _requestsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                   return const Center(child: Padding(
                     padding: EdgeInsets.all(20),
                     child: Text("Loading your requests...", style: TextStyle(color: Colors.grey)),
                   ));
                }
                
                // Show spinner only during initial fetch
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = (snapshot.data?.docs ?? []).toList();

                // Client-side sort to avoid index errors
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
                              const Icon(Icons.volunteer_activism, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(_isLoading ? "Sending request..." : "No requests yet.", 
                                style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final req = VolunteerRequestModel.fromMap(data, doc.id);
                      
                      Color statusColor = Colors.orange;
                      if (req.status == 'Accepted' || req.status == 'Approved') statusColor = Colors.green;
                      if (req.status == 'On the Way') statusColor = Colors.teal;
                      if (req.status == 'Completed') statusColor = Colors.blue;
                      if (req.status == 'Rejected') statusColor = Colors.red;

                      return Card(
                        key: ValueKey(doc.id), // Stable key
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(req.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text("Status: ${req.status}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                               if ((req.status == 'Accepted' || req.status == 'Approved' || req.status == 'On the Way' || req.status == 'Completed') && req.assignedVolunteerName != null) ...[
                                 const SizedBox(height: 4),
                                 Text("Volunteer: ${req.assignedVolunteerName}"),
                                 Text("Contact: ${req.assignedVolunteerContact ?? 'N/A'}"),
                               ],
                               if (req.status == 'Rejected') ...[
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
                                           "Reason: ${req.rejectionReason?.isNotEmpty == true ? req.rejectionReason : 'Not specified'}",
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
                            DateFormat('MMM d, h:mm a').format(req.requestTime.toDate()),
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
}

class _NearbyVolunteersPanel extends StatelessWidget {
  final Position currentPosition;
  const _NearbyVolunteersPanel({required this.currentPosition});

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0; // km
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: 'volunteer')
        .where('isAvailable', isEqualTo: true)
        .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final volunteers = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        
        // Filter by distance
        final nearby = volunteers.where((vol) {
          if (vol['latitude'] == null || vol['longitude'] == null) return false;
          final dist = _calculateDistance(currentPosition.latitude, currentPosition.longitude, vol['latitude'], vol['longitude']);
          return dist <= 15.0; // Within 15km
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
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.1),
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
                child: Text("Available Nearby Volunteers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
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
                            const CircleAvatar(radius: 20, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 24, color: Colors.white)),
                            const SizedBox(height: 8),
                            Flexible(
                              child: Text(
                                nearby[index]['name'] ?? 'Volunteer', 
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
