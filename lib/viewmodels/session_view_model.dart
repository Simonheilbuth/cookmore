import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../repositories/profile_repository.dart';
import '../utils/validators.dart';

/// Keeps track of the profiles on the device and which one is active.
///
/// There is no password: anyone using the device can pick a profile. This
/// is acceptable because profiles only contain non-sensitive cooking data.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._profiles);

  final ProfileRepository _profiles;

  List<Profile> _all = [];
  Profile? _current;
  bool _isLoading = true;

  List<Profile> get profiles => List.unmodifiable(_all);
  Profile? get current => _current;
  bool get isLoading => _isLoading;

  /// Loads profiles and re-opens the profile that was used last time.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _all = await _profiles.getAll();
    final lastId = await _profiles.getLastProfileId();
    _current = _all.where((p) => p.id == lastId).firstOrNull;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> select(Profile profile) async {
    _current = profile;
    await _profiles.setLastProfileId(profile.id);
    notifyListeners();
  }

  /// Goes back to the "Who's cooking?" screen.
  Future<void> switchProfile() async {
    _current = null;
    await _profiles.setLastProfileId(null);
    notifyListeners();
  }

  /// Creates and selects a new profile.
  /// Returns an error message, or null on success.
  Future<String?> createProfile({
    required String nickname,
    required String avatar,
    required DietPreference diet,
  }) async {
    final error = Validators.nickname(nickname);
    if (error != null) return error;
    if (!Profile.avatars.contains(avatar)) return 'Please pick an avatar.';

    final profile = await _profiles.create(
      nickname: Validators.cleanNickname(nickname),
      avatar: avatar,
      diet: diet,
    );
    _all = [..._all, profile];
    await select(profile);
    return null;
  }

  /// Saves changes to the current profile.
  /// Returns an error message, or null on success.
  Future<String?> updateCurrent({
    String? nickname,
    String? avatar,
    DietPreference? diet,
    ThemePreference? themePreference,
  }) async {
    final profile = _current;
    if (profile == null) return 'No profile selected.';
    if (nickname != null) {
      final error = Validators.nickname(nickname);
      if (error != null) return error;
    }
    if (avatar != null && !Profile.avatars.contains(avatar)) {
      return 'Please pick an avatar.';
    }

    final updated = await _profiles.update(profile.copyWith(
      nickname: nickname == null ? null : Validators.cleanNickname(nickname),
      avatar: avatar,
      diet: diet,
      themePreference: themePreference,
    ));
    _current = updated;
    _all = [for (final p in _all) p.id == updated.id ? updated : p];
    notifyListeners();
    return null;
  }

  Future<void> deleteProfile(Profile profile) async {
    await _profiles.delete(profile.id);
    _all = _all.where((p) => p.id != profile.id).toList();
    if (_current?.id == profile.id) _current = null;
    notifyListeners();
  }
}
