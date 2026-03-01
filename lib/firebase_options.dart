import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAAy7ulaaQIkM-g6nbjlqKnsrC6CWxgMpo',
    appId: '1:1093768617024:android:80e4c44950d2adccb193a5',
    messagingSenderId: '1093768617024',
    projectId: 'carenow-19214',
    storageBucket: 'carenow-19214.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBKoB9XRPy-pmnBeqy836b8fd_qyx8G-0E',
    appId: '1:1093768617024:web:031404b1071933feb193a5',
    messagingSenderId: '1093768617024',
    projectId: 'carenow-19214',
    authDomain: 'carenow-19214.firebaseapp.com',
    storageBucket: 'carenow-19214.firebasestorage.app',
    measurementId: 'G-SP1SQRR1FF',
  );
}