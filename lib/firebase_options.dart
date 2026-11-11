// PLACEHOLDER FILE.
//
// This file is replaced automatically when you run:
//
//   flutterfire configure --platforms=android,ios,windows
//
// Until then CookMore runs without cloud backup: all data is still saved
// locally, and the Profile screen shows "Cloud backup is not set up".
// See README.md for the Firebase setup steps.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured yet. Run "flutterfire configure".',
    );
  }
}
