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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBBB1rMUECv3QcmNQJ3IiPVPbrLdhpcCDM',
    appId: '1:229454184250:web:6f9e6a176e2b791ced1a03',
    messagingSenderId: '229454184250',
    projectId: 'attaindance-9d34c',
    authDomain: 'attaindance-9d34c.firebaseapp.com',
    storageBucket: 'attaindance-9d34c.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBBB1rMUECv3QcmNQJ3IiPVPbrLdhpcCDM',
    appId: '1:229454184250:android:6f9e6a176e2b791ced1a03',
    messagingSenderId: '229454184250',
    projectId: 'attaindance-9d34c',
    storageBucket: 'attaindance-9d34c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBBB1rMUECv3QcmNQJ3IiPVPbrLdhpcCDM',
    appId: '1:229454184250:ios:6f9e6a176e2b791ced1a03',
    messagingSenderId: '229454184250',
    projectId: 'attaindance-9d34c',
    storageBucket: 'attaindance-9d34c.firebasestorage.app',
    iosBundleId: 'attaindance.attandance',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBBB1rMUECv3QcmNQJ3IiPVPbrLdhpcCDM',
    appId: '1:229454184250:ios:6f9e6a176e2b791ced1a03',
    messagingSenderId: '229454184250',
    projectId: 'attaindance-9d34c',
    storageBucket: 'attaindance-9d34c.firebasestorage.app',
    iosBundleId: 'attaindance.attandance',
  );
}
