/// Firebase configuration for iwhosebox
/// Auto-generated from google-services.json and GoogleService-Info.plist

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDX2cLEMUgzS5nTboVmTyXXq6KgM_q9Vfs',
    appId: '1:517900350742:android:596d7010c39ab9d45e4c37',
    messagingSenderId: '517900350742',
    projectId: 'iuwhosebox',
    storageBucket: 'iuwhosebox.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD7iPQ_e616YFjKt_g-61_qckV0KRi-RN4',
    appId: '1:517900350742:ios:dfbe4da0cb93c0fc5e4c37',
    messagingSenderId: '517900350742',
    projectId: 'iuwhosebox',
    storageBucket: 'iuwhosebox.firebasestorage.app',
    iosBundleId: 'com.iuwhosebox.app',
  );
}
