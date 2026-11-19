import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Backs up profile data to Supabase (a hosted PostgreSQL database).
///
/// Each installation signs in with Supabase Anonymous Sign-in, which gives a
/// user id without any password or e-mail. Each profile is stored as one row
/// in the table `profile_backups`. Row Level Security (see
/// supabase/schema.sql) only lets a signed-in user read and change rows that
/// carry their own user id.
///
/// This is the only class in the app that knows about Supabase. The rest of
/// the app only uses [isConfigured], [uploadProfile] and [deleteProfile].
class CloudBackupService {
  static const String _table = 'profile_backups';

  bool _ready = false;
  String? _setupProblem;

  /// True when Supabase is configured and initialised.
  bool get isConfigured => _ready;

  /// A user-friendly reason why cloud backup is unavailable, if it is.
  String? get setupProblem => _setupProblem;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> init() async {
    if (!AppConfig.isSupabaseConfigured) {
      _setupProblem = 'Cloud backup is not set up for this build.';
      return;
    }
    try {
      // Restores a saved session from earlier app starts, so the same
      // anonymous user is used every time. No network is needed here.
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      _ready = true;
    } catch (error) {
      debugPrint('CloudBackupService: Supabase init failed: $error');
      _setupProblem = 'Cloud backup could not be started.';
    }
  }

  /// Signs in anonymously if needed and returns the user id.
  /// Throws if the device is offline.
  Future<String> _ensureUserId() async {
    final current = _client.auth.currentUser;
    if (current != null) return current.id;
    final response =
        await _client.auth.signInAnonymously().timeout(AppConfig.requestTimeout);
    final user = response.user;
    if (user == null) {
      throw StateError('Anonymous sign-in returned no user.');
    }
    return user.id;
  }

  /// Uploads a full snapshot of a profile ("last write wins").
  /// An existing row for the same user and profile is replaced.
  Future<void> uploadProfile(String profileId, Map<String, Object?> data) async {
    if (!_ready) return;
    final userId = await _ensureUserId();
    await _client
        .from(_table)
        .upsert(
          {
            'user_id': userId,
            'profile_id': profileId,
            'nickname': data['nickname'],
            'data': data,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id,profile_id',
        )
        .timeout(AppConfig.requestTimeout);
  }

  /// Deletes the cloud copy of a profile.
  Future<void> deleteProfile(String profileId) async {
    if (!_ready) return;
    final userId = await _ensureUserId();
    await _client
        .from(_table)
        .delete()
        .eq('user_id', userId)
        .eq('profile_id', profileId)
        .timeout(AppConfig.requestTimeout);
  }
}
