import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_provider.dart';
import '../../../core/services/notification_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const EditProfileScreen({Key? key, required this.initialData}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _addressController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _bloodGroupController;
  late TextEditingController _conditionsController;
  late TextEditingController _chronicDiseasesController;
  late TextEditingController _allergiesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _emergencyContactController = TextEditingController();
    _bloodGroupController = TextEditingController();
    _conditionsController = TextEditingController();
    _chronicDiseasesController = TextEditingController();
    _allergiesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
           _addressController.text = data['address'] ?? '';
           _emergencyContactController.text = data['emergencyContact'] ?? '';
           _bloodGroupController.text = data['bloodGroup'] ?? '';
           _conditionsController.text = data['conditions'] ?? '';
           _chronicDiseasesController.text = data['chronicDiseases'] ?? '';
           _allergiesController.text = data['allergies'] ?? '';
        });
      }
    } catch (e) {
        debugPrint(e.toString());
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) throw Exception("User not logged in");

      final updates = {
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'bloodGroup': _bloodGroupController.text.trim(),
        'conditions': _conditionsController.text.trim(),
        'chronicDiseases': _chronicDiseasesController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'lastProfileUpdate': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(user.id).update(updates);

      // Trigger Notification for Staff
      final patientName = user.name;
      final patientId = user.id;

      await NotificationService().logNotificationToDb(
        userId: 'staff_broadcast',
        title: 'Patient Information Updated',
        message: 'Patient ${patientName} has updated their profile/medical details.',
        notificationType: 'profile_update',
        targetRole: 'hospitalStaff',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update profile: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile & Medical Info'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Personal Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(labelText: 'Emergency Contact Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              const Text('Medical Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bloodGroupController,
                decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conditionsController,
                decoration: const InputDecoration(labelText: 'Primary Condition(s)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _chronicDiseasesController,
                decoration: const InputDecoration(labelText: 'Chronic Diseases', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(labelText: 'Known Allergies', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
