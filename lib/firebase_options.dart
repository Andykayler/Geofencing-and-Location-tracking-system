// File generated manually.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCUyJyteUFUxt_v_XVIgyptt1-ytuuh5ZM',
    appId: '1:453287365316:web:e1926f7143d4de9eb91791',
    messagingSenderId: '453287365316',
    projectId: 'finalproject-500bd',
    authDomain: 'finalproject-500bd.firebaseapp.com',
    storageBucket: 'finalproject-500bd.appspot.com',
    measurementId: 'G-9GVZ7ZG7YC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCUyJyteUFUxt_v_XVIgyptt1-ytuuh5ZM',
    appId: '1:453287365316:android:e1926f7143d4de9eb91791',
    messagingSenderId: '453287365316',
    projectId: 'finalproject-500bd',
    storageBucket: 'finalproject-500bd.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCUyJyteUFUxt_v_XVIgyptt1-ytuuh5ZM',
    appId: '1:453287365316:ios:e1926f7143d4de9eb91791',
    messagingSenderId: '453287365316',
    projectId: 'finalproject-500bd',
    storageBucket: 'finalproject-500bd.appspot.com',
    iosBundleId: 'com.example.watch_app', 
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCUyJyteUFUxt_v_XVIgyptt1-ytuuh5ZM',
    appId: '1:453287365316:ios:e1926f7143d4de9eb91791',
    messagingSenderId: '453287365316',
    projectId: 'finalproject-500bd',
    storageBucket: 'finalproject-500bd.appspot.com',
    iosBundleId: 'com.example.watch_app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCUyJyteUFUxt_v_XVIgyptt1-ytuuh5ZM',
    appId: '1:453287365316:windows:e1926f7143d4de9eb91791',
    messagingSenderId: '453287365316',
    projectId: 'finalproject-500bd',
    authDomain: 'finalproject-500bd.firebaseapp.com',
    storageBucket: 'finalproject-500bd.appspot.com',
    measurementId: 'G-9GVZ7ZG7YC',
  );
}
