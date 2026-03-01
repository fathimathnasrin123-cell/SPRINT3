
import 'dart:async';
import 'dart:typed_data'; // Added for Int32List
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Local User model
import '../../../models/notification_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Added
import 'package:shared_preferences/shared_preferences.dart';
import '../../../main.dart'; // Access navigatorKey
import '../../features/appointments/screens/live_queue_screen.dart'; // Navigation target
import 'sound_service.dart'; // Added to stop sound

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. SOS Channel (Critical - High Importance, Sound, Vibrate)
  final AndroidNotificationChannel _sosChannel = const AndroidNotificationChannel(
    'sos_channel', // id
    'Emergency SOS Alerts', // title
    description: 'Critical SOS alerts from elderly',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: RawResourceAndroidNotificationSound('sos_alert'), 
  );

  // 2. Queue / Appointment Channel (Medium-High Importance)
  final AndroidNotificationChannel _queueChannel = const AndroidNotificationChannel(
    'queue_channel', // id
    'Queue & Appointments', // title
    description: 'Notifications for live queue and appointments',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // 3. General Channel (Default)
  final AndroidNotificationChannel _generalChannel = const AndroidNotificationChannel(
    'general_channel', // id
    'General Updates', // title
    description: 'General application updates and info',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
  );

  bool _isInitialized = false;
  // Preferences
  bool _userEnabledNotifications = true;
  bool _enableSound = true;
  bool _enableVibrate = true;
  int _tokenAlertThreshold = 5;
  bool _enableAppointmentReminders = true;
  bool _enableMedicineReminders = true;

  bool get areNotificationsEnabled => _userEnabledNotifications;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request Permission
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) print("Error requesting permission: $e");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload == 'live_queue') {
           SoundService.stopLoop(); 
           navigatorKey.currentState?.push(
             MaterialPageRoute(builder: (_) => const LiveQueueScreen(isStaff: false)),
           );
        } else if (response.payload == 'sos') {
           SoundService.stopLoop();
           await _instance.cancelNotification(888); 
           navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      },
    );

    // Create Channels
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    await androidPlugin?.createNotificationChannel(_sosChannel);
    await androidPlugin?.createNotificationChannel(_queueChannel);
    await androidPlugin?.createNotificationChannel(_generalChannel);

    // 4. Handle Foreground Messages (FCM)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       // Check for SOS
       if (message.data['is_sos'] == 'true') {
          showSOSNotification(message.notification?.title ?? "SOS Alert", message.notification?.body ?? "Emergency triggered!");
          return;
       }

      if (!_userEnabledNotifications) return;

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      Map<String, dynamic> data = message.data;

      String type = data['type'] ?? 'general';
      if (type == 'appointment_reminder' && !_enableAppointmentReminders) return;
      if (type == 'medicine_reminder' && !_enableMedicineReminders) return;

      if (notification != null && android != null) {
        // Determine channel based on type
        AndroidNotificationChannel targetChannel = _generalChannel; // Default
        if (type == 'queue' || type == 'appointment' || type == 'token_near') {
           targetChannel = _queueChannel;
        }

        showLocalNotification(
          title: notification.title ?? 'New Notification',
          body: notification.body ?? '',
          priority: data['priority'] ?? 'medium', 
          channelId: targetChannel.id,
          channelName: targetChannel.name
        );
      }
    });

    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
          await _saveDeviceToken(token);
      }
      _firebaseMessaging.onTokenRefresh.listen(_saveDeviceToken);
    } catch (e) {
       if (kDebugMode) print("Error getting token: $e");
    }
    
    _isInitialized = true;
  }
  
  // ... (Preferences methods) ...

  // Helper to show SOS Notification (accessible from background handler if static/instantiated)
  Future<void> showSOSNotification(String title, String body) async {
      // Logic for Insistent Notification (Looping Sound)
      final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
          _sosChannel.id,
          _sosChannel.name,
          channelDescription: _sosChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          ticker: 'ticker',
          fullScreenIntent: true, // Heads up
          category: AndroidNotificationCategory.alarm, // Alarm category
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT = 4
          sound: const RawResourceAndroidNotificationSound('sos_alert'), // If file exists
          // If file doesn't exist, it uses default but INSISTENT makes it loop!
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: const DarwinNotificationDetails(presentSound: true, presentAlert: true, interruptionLevel: InterruptionLevel.critical)
      );

      await _flutterLocalNotificationsPlugin.show(
          888, // Fixed SOS ID
          title,
          body,
          platformChannelSpecifics,
          payload: 'sos'
      );
  }

  // ... (Rest of existing methods) ...


  /// Load preferences specific to the connected Elderly User
  Future<void> loadUserPreferences(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _userEnabledNotifications = prefs.getBool('enable_notifications_$userId') ?? true;
    _enableSound = prefs.getBool('enable_sound_$userId') ?? true;
    _enableVibrate = prefs.getBool('enable_vibrate_$userId') ?? true;
    _tokenAlertThreshold = prefs.getInt('token_alert_threshold_$userId') ?? 5; // Default 5
    _enableAppointmentReminders = prefs.getBool('enable_appointment_reminders_$userId') ?? true;
    _enableMedicineReminders = prefs.getBool('enable_medicine_reminders_$userId') ?? true;
    
    print("Loaded prefs for $userId: threshold=$_tokenAlertThreshold");
  }

  // --- Setting Getters & Setters ---
  
  // ignore: unnecessary_getters_setters
  bool get enableSound => _enableSound;
  bool get enableVibrate => _enableVibrate;
  int get tokenAlertThreshold => _tokenAlertThreshold;
  bool get enableAppointmentReminders => _enableAppointmentReminders;
  bool get enableMedicineReminders => _enableMedicineReminders;

  Future<void> updateSettings({
    required String userId, // Added userId
    bool? enableNotifications,
    bool? enableSound,
    bool? enableVibrate,
    int? tokenAlertThreshold,
    bool? enableAppointmentReminders,
    bool? enableMedicineReminders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (enableNotifications != null) {
      _userEnabledNotifications = enableNotifications;
      await prefs.setBool('enable_notifications_$userId', enableNotifications);
    }
    if (enableSound != null) {
      _enableSound = enableSound;
      await prefs.setBool('enable_sound_$userId', enableSound);
    }
    if (enableVibrate != null) {
      _enableVibrate = enableVibrate;
      await prefs.setBool('enable_vibrate_$userId', enableVibrate);
    }
    if (tokenAlertThreshold != null) {
      _tokenAlertThreshold = tokenAlertThreshold;
      await prefs.setInt('token_alert_threshold_$userId', tokenAlertThreshold);
    }
    if (enableAppointmentReminders != null) {
      _enableAppointmentReminders = enableAppointmentReminders;
      await prefs.setBool('enable_appointment_reminders_$userId', enableAppointmentReminders);
    }
    if (enableMedicineReminders != null) {
      _enableMedicineReminders = enableMedicineReminders;
      await prefs.setBool('enable_medicine_reminders_$userId', enableMedicineReminders);
    }

    // Sync to Firestore for Backend Cloud Functions to respect
    try {
      await _firestore.collection('users').doc(userId).set({
          if (enableNotifications != null) 'enable_notifications': enableNotifications,
          if (enableSound != null) 'enable_sound': enableSound, 
          if (enableVibrate != null) 'enable_vibrate': enableVibrate,
          if (tokenAlertThreshold != null) 'token_alert_threshold': tokenAlertThreshold,
          if (enableAppointmentReminders != null) 'enable_appointment_reminders': enableAppointmentReminders,
          if (enableMedicineReminders != null) 'enable_medicine_reminders': enableMedicineReminders,
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print("Error syncing settings to Firestore: $e");
    }
  }


  Future<void> _saveDeviceToken(String token) async {
    auth.User? user = auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
      }).catchError((e) {
        _firestore.collection('users').doc(user.uid).set({
             'fcmToken': token,
        }, SetOptions(merge: true));
      });
    }
  }

  // --- Displaying Notifications ---

  Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = 0,
    String? payload,
    String priority = 'medium',
    String? channelId,
    String? channelName,
  }) async {
    if (!_userEnabledNotifications) return; 

    // Determine Importance & Priority based on 'priority' string
    bool isCritical = priority == 'critical';
    
    // Play sound/vribute only if globally enabled
    bool playSound = _enableSound;
    bool enableVibration = _enableVibrate;
    
    // Default to General if not specified
    String effectiveChannelId = channelId ?? _generalChannel.id;
    String effectiveChannelName = channelName ?? _generalChannel.name;
    
    // Override if Critical
    if (isCritical) {
       effectiveChannelId = _sosChannel.id;
       effectiveChannelName = _sosChannel.name;
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      effectiveChannelId,
      effectiveChannelName,
      // channelDescription: _channel.description, // Can be omitted or dynamic
      icon: '@mipmap/ic_launcher',
      importance: isCritical ? Importance.max : Importance.high,
      priority: isCritical ? Priority.max : Priority.high,
      playSound: playSound,
      enableVibration: enableVibration,
      ongoing: isCritical, 
      autoCancel: !isCritical, 
      fullScreenIntent: isCritical, 
      category: isCritical ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.status,
      audioAttributesUsage: isCritical ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: playSound,
          interruptionLevel: isCritical ? InterruptionLevel.critical : InterruptionLevel.active,
        ),
      ),
      payload: payload,
    );
  }
  
  // --- Cancel Notification ---
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // --- Queue Monitor ---
  StreamSubscription? _queueSubscription;

  void startQueueMonitoring(String activeTokenDocId, int myTokenNumber, {int? alarmDistance, String? appointmentId, bool alreadyTriggered = false}) async {
    if (_queueSubscription != null) return;
    
    // Check Language
    final prefs = await SharedPreferences.getInstance();
    final String lang = prefs.getString('language_code') ?? 'en'; 
    bool hasTriggeredLocally = alreadyTriggered;

    _queueSubscription = _firestore
        .collection('live_queue')
        .doc(activeTokenDocId) 
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        // Safe cast
        var data = snapshot.data();
        int currentToken =  data != null && data.containsKey('currentToken') ? data['currentToken'] : 0;
        
        int diff = myTokenNumber - currentToken;
        
        // Stop if passed
        if (currentToken >= myTokenNumber) {
           stopQueueMonitoring();
           cancelNotification(999);
           return;
        }

        // Use user preference for threshold, fallback to global setting
        int effectiveThreshold = alarmDistance ?? _tokenAlertThreshold;

        // TRIGGER CONDITION (STRICT EXACT MATCH)
        if (diff > 0 && diff == effectiveThreshold) {
           
           // If we already triggered this specific alert for this appointment, DO NOT replay sound/notif
           if (hasTriggeredLocally) {
             return; 
           }

           // MARK AS TRIGGERED IMMEDIATELY (Local prevention)
           hasTriggeredLocally = true;

           // MARK IN FIRESTORE (Global prevention and State Persistence)
           if (appointmentId != null) {
              FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
                 'alertTriggered': true,
                 'isUpNext': true 
              });
           }
          
           // 1. Show System Notification (Persistent)
           String title = lang == 'ml' ? 'നിങ്ങളുടെ ഊഴം അടിക്കുന്നു!' : 'Your Turn is Approaching!';
           String body = lang == 'ml' 
              ? 'നിങ്ങളുടെ ടോക്കൺ: $myTokenNumber. ($diff പേർ കൂടി)'
              : 'Token #$myTokenNumber. Only $diff people ahead. Please be ready.';
           
           final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
               'queue_alert_channel_v2', 
               'Queue Alerts',
               channelDescription: 'Alarm notifications for Live Queue',
               importance: Importance.max,
               priority: Priority.max,
               styleInformation: BigTextStyleInformation(body),
               fullScreenIntent: true,
               category: AndroidNotificationCategory.alarm,
               playSound: true, // ENABLED system sound
               enableVibration: true,
               ongoing: true, 
               autoCancel: false, 
           );

           final NotificationDetails platformChannelSpecifics = NotificationDetails(
             android: androidPlatformChannelSpecifics, 
             iOS: const DarwinNotificationDetails(presentSound: true, presentAlert: true)
           );

           _flutterLocalNotificationsPlugin.show(
               999, // Fixed ID
               title,
               body,
               platformChannelSpecifics,
               payload: 'live_queue'
           );

           // 2. Play Gentle Alarm Sound
           SoundService.playQueueLoop();
          
        } else {
          // Outside range
          if (!hasTriggeredLocally) {
              cancelNotification(999); 
          }
        }
      }
    });
  }

  void stopQueueMonitoring() {
    _queueSubscription?.cancel();
    _queueSubscription = null;
    cancelNotification(999); // Dismiss notification when monitoring stops (e.g. user views queue)
  }

  // ... Stream and Logging methods ...
  
  Stream<List<NotificationModel>> getUserNotifications(String userId, {String? targetRole}) {
    List<String> targetIds = targetRole == 'hospitalStaff' ? [userId, 'staff_broadcast'] : [userId];

    return _firestore
        .collection('notifications')
        .where('userId', whereIn: targetIds)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        return NotificationModel.fromMap(doc.data(), doc.id);
      }).toList();

      // Sort locally to bypass missing Firestore composite index
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (targetRole != null) {
        // Strict role filtering in-memory
        return notifications.where((n) => n.targetRole == null || n.targetRole == targetRole).toList();
      }
      return notifications;
    });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
    } catch (e) {
      if (kDebugMode) print("Error marking read: $e");
    }
  }

  Future<void> logNotificationToDb({
    required String title,
    required String message, 
    required String notificationType, 
    String? relatedToken, 
    String? userId,
    DateTime? scheduledTime,
    String? status,
    String? appointmentId,
    String? orderId, // Added for orders
    String? scheduleId, // Added for schedules
    String? doctorName, 
    String? department, 
    String priority = 'medium',
    List<String>? targetUserIds, // Broadcast support
    String? targetRole,
  }) async {
    
    // If targetUserIds is provided, we broadcast
    if (targetUserIds != null && targetUserIds.isNotEmpty) {
      final batch = _firestore.batch();
      
      for(String uid in targetUserIds) {
         DocumentReference docRef = _firestore.collection('notifications').doc(); // Auto ID
         batch.set(docRef, {
            'userId': uid, // Individual User ID
            'appointmentId': appointmentId,
            'orderId': orderId,
            'scheduleId': scheduleId,
            'type': notificationType,
            'title': title,
            'message': message,
            'relatedTokenNumber': relatedToken,
            'doctorName': doctorName,
            'department': department,
            'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime) : FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'sentAt': FieldValue.serverTimestamp(),
            'status': status ?? 'sent',
            'isRead': false,
            'priority': priority,
            'targetRole': targetRole,
         });
      }
      
      try {
        await batch.commit();
      } catch (e) {
         if (kDebugMode) print('Failed to batch log: $e');
      }
      return;
    }


    // Single user fallback
    String? targetUserId = userId;
    if (targetUserId == null) {
       auth.User? user = auth.FirebaseAuth.instance.currentUser;
       targetUserId = user?.uid;
    }
    
    if (targetUserId == null) return;

    try {
      await _firestore.collection('notifications').add({
        'userId': targetUserId,
        'appointmentId': appointmentId,
        'orderId': orderId,
        'scheduleId': scheduleId,
        'type': notificationType, 
        'title': title,
        'message': message,
        'relatedTokenNumber': relatedToken,
        'doctorName': doctorName,
        'department': department,
        'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime) : FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'sentAt': FieldValue.serverTimestamp(),
        'status': status ?? 'sent',
        'isRead': false,
        'priority': priority,
        'targetRole': targetRole,
      });
    } catch (e) {
      if (kDebugMode) print('Failed to log notification: $e');
    }
  }
}
