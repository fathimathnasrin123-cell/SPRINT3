import 'package:flutter/material.dart';
import 'package:carenow/l10n/app_localizations.dart';
import 'volunteer_service_screen.dart';
import 'caretaker_service_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Services"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             _ServiceOptionCard(
               title: "Volunteer Service",
               description: "Request help for medicine pickup, daily errands, and basic support.",
               icon: Icons.volunteer_activism,
               color: Colors.teal,
               onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerServiceScreen())),
             ),
             const SizedBox(height: 20),
             _ServiceOptionCard(
               title: "Caretaker Service",
               description: "Book professional caretakers for daily care, medical assistance, and home support.",
               icon: Icons.medical_services,
               color: Colors.indigo,
               onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaretakerServiceScreen())),
             ),
          ],
        ),
      ),
    );
  }
}

class _ServiceOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ServiceOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
               CircleAvatar(
                 radius: 30,
                 backgroundColor: color.withOpacity(0.1),
                 child: Icon(icon, size: 36, color: color),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8),
                     Text(description, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                   ],
                 ),
               ),
               const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
