// File generated by FlutterFire CLI.
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD-rKtal2nlf8jnuxl7B3EL2hIte2-BHXo',
    appId: '1:54640444693:web:b2bc564e23210d5741951c',
    messagingSenderId: '54640444693',
    projectId: 'touristiy',
    authDomain: 'touristiy.firebaseapp.com',
    storageBucket: 'touristiy.firebasestorage.app',
    measurementId: 'G-5T5VQPMRD9',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBeMhAHwXr5Svg_gClzSItc0G0eqqgrDMU',
    appId: '1:54640444693:android:3b42ca46a46863dd41951c',
    messagingSenderId: '54640444693',
    projectId: 'touristiy',
    storageBucket: 'touristiy.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCAiHbKi00zP1KEdHkG6acjZYoFiQNeSmc',
    appId: '1:54640444693:ios:319a12107027379541951c',
    messagingSenderId: '54640444693',
    projectId: 'touristiy',
    storageBucket: 'touristiy.firebasestorage.app',
    androidClientId: '54640444693-721ofqt4a4i6etaqqqb0qgtggdorrvms.apps.googleusercontent.com',
    iosClientId: '54640444693-bauqbts12cctq1410cec4nprtngc7e5j.apps.googleusercontent.com',
    iosBundleId: 'com.example.touristy',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCAiHbKi00zP1KEdHkG6acjZYoFiQNeSmc',
    appId: '1:54640444693:ios:319a12107027379541951c',
    messagingSenderId: '54640444693',
    projectId: 'touristiy',
    storageBucket: 'touristiy.firebasestorage.app',
    androidClientId: '54640444693-721ofqt4a4i6etaqqqb0qgtggdorrvms.apps.googleusercontent.com',
    iosClientId: '54640444693-bauqbts12cctq1410cec4nprtngc7e5j.apps.googleusercontent.com',
    iosBundleId: 'com.example.touristy',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD-rKtal2nlf8jnuxl7B3EL2hIte2-BHXo',
    appId: '1:54640444693:web:454f91211cf874dc41951c',
    messagingSenderId: '54640444693',
    projectId: 'touristiy',
    authDomain: 'touristiy.firebaseapp.com',
    storageBucket: 'touristiy.firebasestorage.app',
    measurementId: 'G-C63H2TPW2C',
  );

}