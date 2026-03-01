import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../medication/screens/medical_records_screen.dart';

import 'edit_profile_screen.dart';
import '../../auth/services/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../auth/models/user_model.dart';

class PatientDetailScreen extends StatelessWidget {
  final Map<String, dynamic> patientData;

  const PatientDetailScreen({Key? key, required this.patientData}) : super(key: key);

  String _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty || dobString == 'Not provided') return 'Unknown';
    try {
      DateTime dob;
      if (dobString.contains('/')) {
        // format: dd/MM/yyyy
        final parts = dobString.split('/');
        dob = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } else if (dobString.contains('-')) {
        // format: yyyy-MM-dd
        dob = DateTime.parse(dobString);
      } else {
        return 'Unknown';
      }
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _editField(BuildContext context, String patientId, String label, String fieldKey, String currentValue, String type) async {
    dynamic newValue = currentValue;
    bool isEmpty = currentValue == 'Not provided' || currentValue == 'None recorded';
    
    if (type == 'date') {
       DateTime initial = DateTime.now();
       if (!isEmpty) {
          try {
             initial = DateFormat('yyyy-MM-dd').parse(currentValue);
          } catch(e) {}
       }
       final picked = await showDatePicker(
         context: context, 
         initialDate: initial, 
         firstDate: DateTime(1900), 
         lastDate: DateTime.now()
       );
       if (picked != null) {
          newValue = DateFormat('yyyy-MM-dd').format(picked);
          try { await FirebaseFirestore.instance.collection('users').doc(patientId).update({fieldKey: newValue}); } catch(e){}
       }
       return;
    }
    
    if (type == 'time') {
       TimeOfDay initial = TimeOfDay.now();
       if (!isEmpty) {
          try {
             final parts = currentValue.split(':');
             if(parts.length >= 2) {
               initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1].split(' ')[0]));
             }
          } catch(e) {}
       }
       final picked = await showTimePicker(context: context, initialTime: initial);
       if (picked != null) {
          if (context.mounted) {
             newValue = picked.format(context);
             try { await FirebaseFirestore.instance.collection('users').doc(patientId).update({fieldKey: newValue}); } catch(e){}
          }
       }
       return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final TextEditingController controller = TextEditingController(text: isEmpty ? '' : currentValue);
        String selectedDropdown = isEmpty ? '' : currentValue;
        final formKey = GlobalKey<FormState>();

        return StatefulBuilder(
          builder: (context, setState) {
             Widget inputWidget;

             if (type == 'gender') {
                List<String> options = ['Male', 'Female', 'Other'];
                if (!options.contains(selectedDropdown)) selectedDropdown = options.first;
                inputWidget = DropdownButtonFormField<String>(
                   value: selectedDropdown,
                   items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                   onChanged: (val) => setState(() => selectedDropdown = val!),
                );
             } else if (type == 'bloodGroup') {
                List<String> options = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
                if (!options.contains(selectedDropdown)) selectedDropdown = options.first;
                inputWidget = DropdownButtonFormField<String>(
                   value: selectedDropdown,
                   items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                   onChanged: (val) => setState(() => selectedDropdown = val!),
                );
             } else if (type == 'phone') {
                inputWidget = TextFormField(
                   controller: controller,
                   keyboardType: TextInputType.phone,
                   validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Cannot be empty';
                      if (!RegExp(r'^\d+$').hasMatch(val.trim())) return 'Invalid number';
                      return null;
                   },
                );
             } else {
                inputWidget = TextFormField(
                   controller: controller,
                   maxLines: type == 'text' ? 3 : 1,
                   validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Cannot be empty';
                      return null;
                   }
                );
             }

             return AlertDialog(
               title: Text(isEmpty ? "Add $label" : "Edit $label"),
               content: Form(
                 key: formKey,
                 child: inputWidget
               ),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                 ElevatedButton(
                   onPressed: () async {
                      if (formKey.currentState!.validate()) {
                         String finalValue = (type == 'gender' || type == 'bloodGroup') ? selectedDropdown : controller.text.trim();
                         try {
                           await FirebaseFirestore.instance.collection('users').doc(patientId).update({fieldKey: finalValue});
                           if (ctx.mounted) Navigator.pop(ctx);
                         } catch (e) {
                           debugPrint(e.toString());
                           if (ctx.mounted) Navigator.pop(ctx);
                         }
                      }
                   },
                   child: const Text("Save")
                 )
               ]
             );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final String patientId = patientData['uid'] ?? patientData['id'] ?? '';
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final bool isStaff = currentUser?.role == UserRole.hospitalStaff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Details'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
           if (currentUser?.role == UserRole.elderly && currentUser?.id == patientId)
              IconButton(
                 icon: const Icon(Icons.edit),
                 tooltip: "Edit Profile",
                 onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(initialData: patientData)));
                 },
              )
        ],
      ),
      body: patientId.isEmpty 
          ? const Center(child: Text("Missing Patient ID"))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(patientId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Data is temporarily unavailable."));
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = Map<String, dynamic>.from(patientData);
                if (snapshot.hasData && snapshot.data!.exists) {
                   data.addAll(snapshot.data!.data() as Map<String, dynamic>);
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        color: Colors.teal.shade50,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.teal,
                              child: Text(
                                (data['name'] ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 32, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data['name'] ?? 'Unknown Patient',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              data['uniqueId'] ?? 'No ID',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.teal.shade200)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _DetailRow(icon: Icons.cake, label: 'Date of Birth', value: data['dob'] ?? data['dateOfBirth'] ?? 'Not provided', isEditable: false, onEdit: () => _editField(context, patientId, 'Date of Birth', 'dob', data['dob'] ?? data['dateOfBirth'] ?? 'Not provided', 'date')),
                                    const Divider(),
                                    _DetailRow(icon: Icons.calendar_month, label: 'Age', value: _calculateAge(data['dob'] ?? data['dateOfBirth']), isEditable: false),
                                    const Divider(),
                                    _DetailRow(icon: Icons.person, label: 'Gender', value: data['gender'] ?? 'Not provided', isEditable: false, onEdit: () => _editField(context, patientId, 'Gender', 'gender', data['gender'] ?? 'Not provided', 'gender')),
                                    const Divider(),
                                    _DetailRow(icon: Icons.phone, label: 'Contact Number', value: data['contactNumber'] ?? data['phone'] ?? 'Not provided', isEditable: false, onEdit: () => _editField(context, patientId, 'Contact Number', 'contactNumber', data['contactNumber'] ?? data['phone'] ?? 'Not provided', 'phone')),
                                    const Divider(),
                                    _DetailRow(icon: Icons.location_on, label: 'Address', value: data['address'] ?? 'Not provided', isEditable: isStaff, onEdit: () => _editField(context, patientId, 'Address', 'address', data['address'] ?? 'Not provided', 'text')),
                                    const Divider(),
                                    _DetailRow(icon: Icons.emergency, label: 'Emergency Contact', value: data['emergencyContact'] ?? 'Not provided', isEditable: isStaff, onEdit: () => _editField(context, patientId, 'Emergency Contact', 'emergencyContact', data['emergencyContact'] ?? 'Not provided', 'phone')),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Medical Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _DetailRow(icon: Icons.bloodtype, label: 'Blood Group', value: data['bloodGroup'] ?? 'Not provided', iconColor: Colors.red, isEditable: isStaff, onEdit: () => _editField(context, patientId, 'Blood Group', 'bloodGroup', data['bloodGroup'] ?? 'Not provided', 'bloodGroup')),
                                    const Divider(),
                                    _DetailRow(icon: Icons.medical_services, label: 'Primary Condition', value: data['conditions'] ?? 'None recorded', iconColor: Colors.blue, isEditable: isStaff, onEdit: () => _editField(context, patientId, 'Primary Condition', 'conditions', data['conditions'] ?? 'None recorded', 'text')),
                                    const Divider(),
                                    _DetailRow(icon: Icons.sick, label: 'Chronic Diseases', value: data['chronicDiseases'] ?? 'None recorded', iconColor: Colors.purple, isEditable: isStaff, onEdit: () => _editField(context, patientId, 'Chronic Diseases', 'chronicDiseases', data['chronicDiseases'] ?? 'None recorded', 'text')),
                                    const Divider(),
                                    _DetailRow(icon: Icons.warning, label: 'Known Allergies', value: data['allergies'] ?? 'None recorded', iconColor: Colors.orange, isEditable: isStaff, onEdit: () => _editField(context, patientId, 'Known Allergies', 'allergies', data['allergies'] ?? 'None recorded', 'text')),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text("Doctor & Appointments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                            const SizedBox(height: 12),
                            _AppointmentsSection(patientId: patientId),
                            const SizedBox(height: 24),
                            const Text("Documents & Reports", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => MedicalRecordsScreen(patientId: patientId))
                                  );
                                },
                                icon: const Icon(Icons.folder_shared),
                                label: const Text("View & Upload Medical Records"),
                                style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Colors.blue.shade50,
                                    foregroundColor: Colors.blue.shade900,
                                    side: BorderSide(color: Colors.blue.shade200),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              }
          )
    );
  }
}

class _AppointmentsSection extends StatelessWidget {
  final String patientId;

  const _AppointmentsSection({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (snapshot.hasError) {
          // Log error for developers and display fallback message instead of empty string
          debugPrint("Appointments Stream Error: ${snapshot.error}");
          return const Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text("Unable to load appointments. Please check connection.", style: TextStyle(color: Colors.red))),
            ),
          );
        }

        var docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text("No appointments scheduled at the moment.", style: TextStyle(color: Colors.grey))),
            ),
          );
        }

        // Sort on client side to avoid missing composite index requirement
        docs = docs.toList();
        docs.sort((a, b) {
           final aDate = (a.data() as Map<String, dynamic>)['appointmentDate'] as Timestamp?;
           final bDate = (b.data() as Map<String, dynamic>)['appointmentDate'] as Timestamp?;
           if (aDate == null) return 1;
           if (bDate == null) return -1;
           return bDate.compareTo(aDate); // Descending
        });
        
        // Take top 5
        final displayDocs = docs.take(5).toList();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: displayDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final doctorName = data['doctorName'] ?? 'Unknown Doctor';
              final department = data['department'] ?? 'General';
              final hospitalName = data['hospitalName'] ?? 'CareNow Hospital';
              final date = (data['appointmentDate'] as Timestamp).toDate();
              final status = data['status'] ?? 'pending';
              
              Color statusColor = Colors.grey;
              if (status == 'approved' || status == 'serving' || status == 'waiting') statusColor = Colors.green;
              if (status == 'pending') statusColor = Colors.orange;
              if (status == 'rejected') statusColor = Colors.red;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(Icons.person, color: statusColor),
                ),
                title: Text(doctorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$department • $hospitalName"),
                    const SizedBox(height: 4),
                    Text(DateFormat('MMM dd, yyyy - hh:mm a').format(date), style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.w600)),
                  ],
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10)),
                  backgroundColor: statusColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              );
            }).toList()
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final bool isEditable;
  final VoidCallback? onEdit;

  const _DetailRow({
    required this.icon, 
    required this.label, 
    required this.value, 
    this.iconColor,
    this.isEditable = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    bool isEmpty = value == 'Not provided' || value == 'None recorded';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    value, 
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isEmpty ? Colors.grey : Colors.black87), 
                    textAlign: TextAlign.right
                  ),
                ),
                if (isEditable) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onEdit,
                    child: Text(
                      isEmpty ? "Add" : "Edit",
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}
