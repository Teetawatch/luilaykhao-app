import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.luilaykhao.app',
  );
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );

  static String get appId {
    return defaultTargetPlatform == TargetPlatform.iOS ? iosAppId : androidAppId;
  }

  static bool get hasDartDefines {
    return projectId.isNotEmpty &&
        appId.isNotEmpty &&
        apiKey.isNotEmpty &&
        messagingSenderId.isNotEmpty;
  }

  static FirebaseOptions? get options {
    if (!hasDartDefines) return null;

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      iosBundleId: iosBundleId,
    );
  }
}
