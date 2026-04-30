import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );

  static bool get hasDartDefines {
    return projectId.isNotEmpty &&
        androidAppId.isNotEmpty &&
        apiKey.isNotEmpty &&
        messagingSenderId.isNotEmpty;
  }

  static FirebaseOptions? get options {
    if (!hasDartDefines) return null;

    return const FirebaseOptions(
      apiKey: apiKey,
      appId: androidAppId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
    );
  }
}
