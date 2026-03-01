import 'package:flutter/material.dart';
import '../../sos/services/sos_service.dart';
import '../../../core/services/sound_service.dart';
import '../../auth/models/user_model.dart';

class SOSButton extends StatefulWidget {
  final UserRole role; // To tag 'triggeredBy'
  
  const SOSButton({super.key, required this.role});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> {
  final SOSService _sosService = SOSService();
  bool _isLoading = false;

  Future<void> _handlePress() async {
    // Show Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Emergency SOS", style: TextStyle(color: Colors.red)),
        content: const SingleChildScrollView(
          child: Text(
            "Are you sure you want to send an SOS alert? This will share your live location with staff.",
            style: TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SEND SOS", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _sosService.triggerSOS(role: widget.role.name);
        SoundService.vibrate(); 
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text("SOS Acknowledged! Help is on the way."), 
               backgroundColor: Colors.green,
               duration: Duration(seconds: 5),
             ),
           );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Error sending SOS: $e"), backgroundColor: Colors.black),
           );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handlePress,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 5,
        ),
        icon: _isLoading 
           ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
           : const Icon(Icons.emergency_share, size: 32),
        label: Text(
          _isLoading ? "SENDING..." : "EMERGENCY SOS",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
    );
  }
}
