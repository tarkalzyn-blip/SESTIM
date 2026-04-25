import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you are missing the web configuration in your JSON.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you are missing the ios configuration in your JSON.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcZeccQr2c1YC3jOlIJHYE-dj32_qaAfg',
    appId: '1:834883426579:android:57178e8fbc27c9176f62e6',
    messagingSenderId: '834883426579',
    projectId: 'sestim-a6d2a',
    storageBucket: 'sestim-a6d2a.firebasestorage.app',
  );
}
