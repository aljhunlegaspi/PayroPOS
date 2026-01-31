import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSyAi-qzoD4CGW-kEu69fz0ZwRnBA_X4RkiE',
    appId: '1:294162001804:web:2b823e7571f7317099f0a9',
    messagingSenderId: '294162001804',
    projectId: 'payro-pos',
    authDomain: 'payro-pos.firebaseapp.com',
    storageBucket: 'payro-pos.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAhRvyUwWUSEphtI4ZTs8ho2jVmWvHNBeU',
    appId: '1:294162001804:android:89b296ed2716ea3699f0a9',
    messagingSenderId: '294162001804',
    projectId: 'payro-pos',
    storageBucket: 'payro-pos.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAi-qzoD4CGW-kEu69fz0ZwRnBA_X4RkiE',
    appId: '1:294162001804:ios:payropos',
    messagingSenderId: '294162001804',
    projectId: 'payro-pos',
    storageBucket: 'payro-pos.firebasestorage.app',
    iosBundleId: 'com.payropos.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAi-qzoD4CGW-kEu69fz0ZwRnBA_X4RkiE',
    appId: '1:294162001804:ios:payropos',
    messagingSenderId: '294162001804',
    projectId: 'payro-pos',
    storageBucket: 'payro-pos.firebasestorage.app',
    iosBundleId: 'com.payropos.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAi-qzoD4CGW-kEu69fz0ZwRnBA_X4RkiE',
    appId: '1:294162001804:web:2b823e7571f7317099f0a9',
    messagingSenderId: '294162001804',
    projectId: 'payro-pos',
    authDomain: 'payro-pos.firebaseapp.com',
    storageBucket: 'payro-pos.firebasestorage.app',
  );
}
