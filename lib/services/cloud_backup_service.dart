import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../firebase_options.dart';

/// Backs up profile data to Cloud Firestore.
///
/// Each installation signs in with Firebase Anonymous Authentication, which
/// gives a user id without any password or e-mail. Data is stored under
/// `users/{uid}/profiles/{profileId}`, and the Firestore security rules
/// (firestore.rules) only allow a signed-in user to access their own uid.
class CloudBackupService {
  bool _firebaseReady = false;
  String? _setupProblem;

  /// True when Firebase is configured and initialised.
  bool get isConfigured => _firebaseReady;

  /// A user-friendly reason why cloud backup is unavailable, if it is.
  String? get setupProblem => _setupProblem;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseReady = true;
    } on UnsupportedError {
      _setupProblem = 'Cloud backup is not set up for this build.';
    } catch (error) {
      debugPrint('CloudBackupService: Firebase init failed: $error');
      _setupProblem = 'Cloud backup could not be started.';
    }
  }

  /// Signs in anonymously if needed and returns the user id.
  /// Throws if the device is offline.
  Future<String> _ensureUserId() async {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current != null) return current.uid;
    final credential =
        await auth.signInAnonymously().timeout(AppConfig.requestTimeout);
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous sign-in returned no user.');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _profileDoc(
    String uid,
    String profileId,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profiles')
        .doc(profileId);
  }

  /// Uploads a full snapshot of a profile ("last write wins").
  Future<void> uploadProfile(String profileId, Map<String, Object?> data) async {
    if (!_firebaseReady) return;
    final uid = await _ensureUserId();
    await _profileDoc(uid, profileId)
        .set({...data, 'syncedAt': FieldValue.serverTimestamp()})
        .timeout(AppConfig.requestTimeout);
  }

  /// Deletes the cloud copy of a profile.
  Future<void> deleteProfile(String profileId) async {
    if (!_firebaseReady) return;
    final uid = await _ensureUserId();
    await _profileDoc(uid, profileId)
        .delete()
        .timeout(AppConfig.requestTimeout);
  }
}
