import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../../models/notification_model.dart';
import 'package:carenow/l10n/app_localizations.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  List<NotificationModel> _cachedNotifications = [];
  bool _isLoading = true;
  bool _hasInitialFetchFailed = false;
  StreamSubscription<List<NotificationModel>>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  void _startListening() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    _subscription = NotificationService()
        .getUserNotifications(user.id, targetRole: user.role.name)
        .listen((data) {
      if (mounted) {
        setState(() {
          _cachedNotifications = data;
          _isLoading = false;
          _hasInitialFetchFailed = false;
        });
      }
    }, onError: (error) {
      debugPrint("Notification Error: $error");
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_cachedNotifications.isEmpty) {
            _hasInitialFetchFailed = true;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    // final l10n = AppLocalizations.of(context)!;
    // final locale = Localizations.localeOf(context).languageCode;

    if (user == null) return const Scaffold(body: Center(child: Text("Please login")));

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          NotificationService().logNotificationToDb(
            title: "Test System Alert",
            message: "This is a manually triggered notification to verify Firestore writes.",
            notificationType: "info",
            userId: user.id,
            targetRole: user.role.name,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creating test notification...')),
          );
        },
        label: const Text("Test Write"),
        icon: const Icon(Icons.add_alert),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasInitialFetchFailed && _cachedNotifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Unable to load notifications. Please try again later.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_cachedNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No notifications', style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _cachedNotifications.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final notification = _cachedNotifications[index];
        final isRead = notification.isRead;

        // Map type to icon/color
        IconData icon;
        Color color;

        if (notification.priority == 'critical') {
          icon = Icons.gpp_maybe;
          color = Colors.red.shade900;
        } else {
          switch (notification.notificationType) {
            case 'alert':
            case 'token_near':
              icon = Icons.warning_rounded;
              color = Colors.red;
              break;
            case 'warning':
            case 'reminder':
            case 'medicine_reminder':
            case 'appointment_reminder':
              icon = Icons.alarm;
              color = Colors.orange;
              break;
            case 'order_update':
              icon = Icons.shopping_bag;
              color = Colors.green;
              break;
            case 'schedule_update':
              icon = Icons.calendar_month;
              color = Colors.teal;
              break;
            case 'info':
            default:
              icon = Icons.info_outline;
              color = Colors.blue;
          }
        }

        return Card(
          elevation: isRead ? 0 : 2,
          color: notification.priority == 'critical' && !isRead
              ? Colors.red.shade50
              : (isRead ? Colors.white : Colors.blue.shade50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: notification.priority == 'critical' && !isRead
                  ? const BorderSide(color: Colors.red, width: 2)
                  : (isRead ? BorderSide(color: Colors.grey.shade200) : BorderSide.none)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            title: Text(
              notification.title,
              style: GoogleFonts.outfit(
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(notification.message, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                Text(
                  DateFormat('MMM d, h:mm a').format(notification.createdAt),
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            onTap: () {
              if (!isRead) {
                NotificationService().markAsRead(notification.id);
                // The stream will naturally push the updated notification back down
              }
              
              if (notification.orderId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Navigating to Order: ${notification.orderId}')),
                );
              } else if (notification.scheduleId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Navigating to Schedule: ${notification.scheduleId}')),
                );
              } else if (notification.appointmentId != null && notification.notificationType == 'token_near') {
                 // Example of existing deep linking to live queue
                 Navigator.pushNamed(context, '/live_queue');
              } else if (notification.appointmentId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Navigating to Appointment: ${notification.appointmentId}')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
