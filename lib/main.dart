import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/features/auth/services/auth_provider.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/onboarding/screens/language_selection_screen.dart';
import 'src/features/auth/screens/login_screen.dart';
import 'src/features/dashboard/screens/dashboard_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:carenow/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Added
import 'src/core/services/notification_service.dart';
import 'src/features/sos/screens/global_system_manager.dart'; // Added
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
  
  // Initialize Notification Service to set up channels
  final notificationService = NotificationService();
  await notificationService.initialize(); // Ensure channels are created

  // Handle SOS specifically for Loud/Looping/Insistent behavior
  if (message.data['is_sos'] == 'true' || message.data['type'] == 'sos') {
      await notificationService.showSOSNotification(
          message.notification?.title ?? "🚨 Emergency SOS Alert", 
          message.notification?.body ?? "Emergency triggered! Tap to open."
      );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
  
  // Set up background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize Notification Service (Local & FCM)
  try {
    await NotificationService().initialize();
  } catch (e) {
    print("Notification initialization failed: $e");
  }
  
  runApp(const CareNowApp());
}

class CareNowApp extends StatelessWidget {
  const CareNowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return MaterialApp(
      title: 'CareNow',
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // Forced Light Mode as requested
      builder: (context, child) {
        return GlobalSystemManager(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(authProvider.textScaleFactor)),
            child: child!,
          ),
        );
      },
      locale: authProvider.currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('ml'), // Malayalam
      ],
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (auth.isLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (auth.isFirstLaunch) {
            return const LanguageSelectionScreen();
          }

          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }

          return const DashboardScreenWrapper();
        },
      ),
    );
  }
}
