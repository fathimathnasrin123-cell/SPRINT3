import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_provider.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import 'package:carenow/l10n/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.elderly; // Default role
  
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  
  // Extra fields controllers
  final _dobController = TextEditingController();
  final _elderlyIdController = TextEditingController();
  final _staffIdController = TextEditingController();
  
  // Added for Elderly Form
  String? _selectedRelationship;
  String? _selectedGender; 
  String? _selectedBloodGroup;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  int? _calculatedAge;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
         _dobController.text = "${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}";
         final now = DateTime.now();
         int age = now.year - picked.year;
         if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
           age--;
         }
         _calculatedAge = age;
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _elderlyIdController.dispose();
    _staffIdController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();
      
      if (password != confirmPassword) {
         // Localized error message
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.passwordsDoNotMatch), backgroundColor: Colors.red));
         setState(() => _isLoading = false);
         return;
      }
      
      final role = _selectedRole;
      Map<String, dynamic> additionalData = {};

      switch (role) {
        case UserRole.elderly: 
          if (_selectedGender == null) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a gender'), backgroundColor: Colors.red));
             setState(() => _isLoading = false);
             return;
          }
          if (_selectedBloodGroup == null) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a blood group'), backgroundColor: Colors.red));
             setState(() => _isLoading = false);
             return;
          }
          additionalData['dob'] = _dobController.text.trim();
          additionalData['gender'] = _selectedGender;
          additionalData['contactNumber'] = _contactController.text.trim();
          additionalData['address'] = _addressController.text.trim();
          additionalData['bloodGroup'] = _selectedBloodGroup;
          break;
        case UserRole.caregiver: 
          if (_selectedRelationship != null) additionalData['relationship'] = _selectedRelationship;
          additionalData['contactNumber'] = _contactController.text.trim();
          break;
        case UserRole.hospitalStaff: 
          if (_staffIdController.text.isNotEmpty) additionalData['staffId'] = _staffIdController.text.trim();
          additionalData['isApproved'] = false; // Staff usually needs approval
          break;
        case UserRole.volunteer:
          additionalData['isApproved'] = true; 
          additionalData['contactNumber'] = _contactController.text.trim();
          break;
      }
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.register(email, password, name, role, additionalData);

      if (mounted) {
         Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const DashboardScreenWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createAccount),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView( // Main ScrollView
          padding: const EdgeInsets.all(16),
          child: Column(
             children: [
               // ROLE SELECTION DROPDOWN
               DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  decoration: InputDecoration(
                    labelText: l10n.selectRole,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                     DropdownMenuItem(value: UserRole.elderly, child: Text(l10n.elderly)),
                     DropdownMenuItem(value: UserRole.caregiver, child: Text(l10n.caregiverFamily)), // Simplified logic uses caregiverFamily key
                     DropdownMenuItem(value: UserRole.hospitalStaff, child: Text(l10n.staff)),
                     DropdownMenuItem(value: UserRole.volunteer, child: Text(l10n.volunteer)),
                  ],
                  onChanged: (UserRole? newVal) {
                    if (newVal != null) {
                       setState(() => _selectedRole = newVal);
                    }
                  },
               ),
               const SizedBox(height: 20),
               
               // Dynamic Form Content based on Role
               if (_selectedRole == UserRole.elderly) ...[
                  _buildElderlyForm(l10n),
               ] else if (_selectedRole == UserRole.caregiver) ...[
                  _buildCaregiverForm(l10n),
               ] else if (_selectedRole == UserRole.hospitalStaff) ...[
                  _buildStaffForm(l10n),
               ] else if (_selectedRole == UserRole.volunteer) ...[
                  _buildVolunteerForm(l10n),
               ],
             ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
           child: _isLoading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(l10n.completeRegistration),
        ),
      ),
    );
  }

  Widget _buildCommonFields(AppLocalizations l10n) {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          // Label changed to 'Username' as requested, with mandatory *
          decoration: InputDecoration(
            labelText: "${l10n.username} *", 
            prefixIcon: const Icon(Icons.person)
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return l10n.usernameError;
            if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) return 'Use only letters';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: "${l10n.email} *", 
            prefixIcon: const Icon(Icons.email)
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter an email'; // Should be localized potentially
            if (!value.contains('@')) return 'Please enter a valid email';
            if (!value.endsWith('@gmail.com') && !value.endsWith('@yahoo.com')) {
              return 'Only @gmail.com or @yahoo.com allowed'; 
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: "${l10n.password} *",
            prefixIcon: const Icon(Icons.lock),
            helperText: l10n.passwordHelper,
            helperMaxLines: 2,
            helperStyle: const TextStyle(color: Colors.grey, fontSize: 12), 
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
          obscureText: !_isPasswordVisible,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return l10n.incorrectPassword; // Reusing "incorrect password" as generic "enter password", better to add specific key but sticking to available
            if (value.length < 6) return 'Password must be at least 6 characters';
            if (!RegExp(r'(?=.*?[0-9])').hasMatch(value)) return 'Must contain at least one number';
            if (!RegExp(r'(?=.*?[#?!@$%^&*-])').hasMatch(value)) return 'Must contain at least one special character';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: "${l10n.confirmPassword} *",
            prefixIcon: const Icon(Icons.lock_clock),
            suffixIcon: IconButton(
              icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
          ),
          obscureText: !_isConfirmPasswordVisible,
          validator: (value) {
             if (value == null || value.isEmpty) return l10n.confirmPassword;
             if (value != _passwordController.text) return l10n.passwordsDoNotMatch;
             return null;
          },
        ),
      ],
    );
  }

  Widget _buildElderlyForm(AppLocalizations l10n) {
    // Note: ScrollView removed from here as we have a parent SingleChildScrollView
    return Column(
        children: [
          Text(l10n.simplifiedRegistration, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          _buildCommonFields(l10n),
          const SizedBox(height: 12),
          // Gender Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.grey),
                const SizedBox(width: 12),
                const Text("Gender *", style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          Radio<String>(
                            value: 'Male',
                            groupValue: _selectedGender,
                            onChanged: (value) => setState(() => _selectedGender = value),
                          ),
                          const Text('Male'),
                        ],
                      ),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'Female',
                            groupValue: _selectedGender,
                            onChanged: (value) => setState(() => _selectedGender = value),
                          ),
                          const Text('Female'),
                        ],
                      ),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'Other',
                            groupValue: _selectedGender,
                            onChanged: (value) => setState(() => _selectedGender = value),
                          ),
                          const Text('Other'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _dobController,
            readOnly: true,
            onTap: () => _selectDate(context),
            decoration: InputDecoration(
              labelText: "${l10n.dateOfBirth} *", 
              prefixIcon: const Icon(Icons.calendar_today),
              errorText: (_calculatedAge != null && _calculatedAge! < 50) ? l10n.ageEligibilityError : null,
            ),
            validator: (value) {
               if (value == null || value.isEmpty) return 'Date of Birth is mandatory';
               if (_calculatedAge != null && _calculatedAge! < 50) return l10n.ageEligibilityError;
               return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: "Contact Number *",
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Primary Contact Number is required';
              if (!RegExp(r'^\d+$').hasMatch(value)) return 'Please enter a valid numeric phone number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Address *",
              prefixIcon: Icon(Icons.location_on),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Address is required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedBloodGroup,
            decoration: const InputDecoration(
              labelText: "Blood Group *",
              prefixIcon: Icon(Icons.bloodtype),
            ),
            items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                .toList(),
            onChanged: (val) => setState(() => _selectedBloodGroup = val),
            validator: (value) => value == null ? 'Please select a blood group' : null,
          ),
        ],
    );
  }

  Widget _buildCaregiverForm(AppLocalizations l10n) {
      return Column(
        children: [
           Text(l10n.linkToElderly, style: const TextStyle(color: Colors.grey)),
           const SizedBox(height: 20),
          _buildCommonFields(l10n),
          const SizedBox(height: 12),
           // Removed Link ID field per instructions
          // TextFormField(
          //   controller: _elderlyIdController,
          //   decoration: InputDecoration(labelText: "${l10n.elderlyLinkId} *", prefixIcon: const Icon(Icons.link)),
          // ),
          // const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedRelationship,
            decoration: InputDecoration(
              labelText: "${l10n.relationship} *", 
              prefixIcon: const Icon(Icons.people),
            ),
            items: [
                DropdownMenuItem(value: 'Caregiver', child: Text(l10n.caregiver)),
                DropdownMenuItem(value: 'Family Member', child: Text(l10n.familyMember)), 
            ],
            onChanged: (newValue) {
              setState(() {
                _selectedRelationship = newValue;
              });
            },
            validator: (value) => value == null ? 'Please select a relationship' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Contact Number *",
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Contact number is required';
              if (!RegExp(r'^\d{10}$').hasMatch(value)) return 'Enter a valid 10-digit number';
              return null;
            },
          ),
        ],
    );
  }

  Widget _buildStaffForm(AppLocalizations l10n) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.adminApprovalRequired)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildCommonFields(l10n),
          const SizedBox(height: 12),
          TextFormField(
            controller: _staffIdController,
            decoration: InputDecoration(labelText: "${l10n.staffIdOnly} *", prefixIcon: const Icon(Icons.badge)),
            validator: (value) => value == null || value.isEmpty ? 'Staff ID is required' : null,
          ),
        ],
    );
  }

  Widget _buildVolunteerForm(AppLocalizations l10n) {
    return Column(
        children: [
          // Localized Alert Removed
          const SizedBox(height: 10),
          Text(l10n.joinVolunteer, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          _buildCommonFields(l10n),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Contact Number *",
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Contact number is required';
              if (!RegExp(r'^\d{10}$').hasMatch(value)) return 'Enter a valid 10-digit number';
              return null;
            },
          ),
          // Add extra volunteer fields if needed
        ],
    );
  }
}
