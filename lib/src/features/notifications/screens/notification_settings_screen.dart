import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/services/auth_provider.dart';
import '../../auth/models/user_model.dart';
import 'package:carenow/l10n/app_localizations.dart';
import '../../../core/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _service = NotificationService();
  
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrateEnabled = true;
  // _tokenThreshold removed
  bool _apptReminders = true;
  bool _medReminders = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    // Ensure service is init to read latest prefs
    await _service.initialize();
    await _service.loadUserPreferences(user.id);
    
    setState(() {
      _notificationsEnabled = _service.areNotificationsEnabled;
      _soundEnabled = _service.enableSound;
      _vibrateEnabled = _service.enableVibrate;
      // _tokenThreshold removed
      _apptReminders = _service.enableAppointmentReminders;
      _medReminders = _service.enableMedicineReminders;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
     final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
     if (user == null) return;

     await _service.updateSettings(
       userId: user.id,
       enableNotifications: _notificationsEnabled,
       enableSound: _soundEnabled,
       enableVibrate: _vibrateEnabled,
       // tokenAlertThreshold removed
       enableAppointmentReminders: _apptReminders,
       enableMedicineReminders: _medReminders,
     );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = Provider.of<AuthProvider>(context, listen: false).currentUser?.role; // Get Role

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationSettings, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Master Switch
          SwitchListTile(
            title: Text(l10n.enableNotifications, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(l10n.enableNotificationsDesc, style: GoogleFonts.outfit(color: Colors.grey)),
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              _saveSettings();
            },
            activeThumbColor: Colors.teal,
          ),
          const Divider(),
          
          if (_notificationsEnabled) ...[
             const SizedBox(height: 10),
             Text(l10n.alertPreferences, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16)),
             const SizedBox(height: 10),

             SwitchListTile(
               title: Text(l10n.sound, style: GoogleFonts.outfit()),
               value: _soundEnabled,
               onChanged: (val) {
                 setState(() => _soundEnabled = val);
                 _saveSettings();
               },
             ),
             SwitchListTile(
               title: Text(l10n.vibration, style: GoogleFonts.outfit()),
               value: _vibrateEnabled,
               onChanged: (val) {
                 setState(() => _vibrateEnabled = val);
                 _saveSettings();
               },
             ),

             // HIDE ADVANCED OPTIONS FOR STAFF & VOLUNTEER
             if (role != UserRole.hospitalStaff && role != UserRole.volunteer) ...[
                 const Divider(),
                 const SizedBox(height: 10),
                 
                 // Smart Reminders (Token Alerts Removed)
                 Text(l10n.smartReminders, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16)),
                 
                 SwitchListTile(
                   title: Text(l10n.appointmentReminders, style: GoogleFonts.outfit()),
                   subtitle: Text(l10n.appointmentRemindersDesc, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                   value: _apptReminders,
                   onChanged: (val) {
                     setState(() => _apptReminders = val);
                     _saveSettings();
                   },
                 ),
                  SwitchListTile(
                   title: Text(l10n.medicineReminders, style: GoogleFonts.outfit()),
                   subtitle: Text(l10n.medicineRemindersDesc, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
                   value: _medReminders,
                   onChanged: (val) {
                     setState(() => _medReminders = val);
                     _saveSettings();
                   },
                 ),
             ],

          ] else ...[
             Padding(
               padding: const EdgeInsets.all(20),
               child: Center(
                 child: Text(
                   l10n.notificationsDisabledMsg,
                   textAlign: TextAlign.center,
                   style: const TextStyle(color: Colors.grey),
                 ),
               ),
             )
          ]
        ],
      ),
    );
  }
}
