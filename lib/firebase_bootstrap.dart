import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'src/firebase_web_options.dart';

/// Initializes Firebase.
///
/// - **Web:** uses [kFirebaseOptionsWeb] (no `firebase_options` JSON in repo).
/// - **Android / iOS:** uses native config (`google-services.json`,
///   `GoogleService-Info.plist`).
///
/// Call after [WidgetsFlutterBinding.ensureInitialized].
Future<void> initializeFirebaseApp() async {
  if (kIsWeb) {
    await Firebase.initializeApp(options: kFirebaseOptionsWeb);
  } else {
    await Firebase.initializeApp();
  }
}
