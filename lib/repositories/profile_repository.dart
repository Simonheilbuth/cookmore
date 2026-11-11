import 'dart:math';

import '../models/profile.dart';
import '../services/local_database.dart';
import '../services/sync_queue.dart';
import 'change_notifying_repository.dart';

/// Stores profiles locally and queues them for cloud backup.
class ProfileRepository with ChangeNotifyingRepository {
  ProfileRepository(this._database, this._syncQueue);

  final LocalDatabase _database;
  final SyncQueue _syncQueue;

  static const String _lastProfileKey = 'last_profile_id';
  final Random _random = Random.secure();

  Future<List<Profile>> getAll() async {
    final rows = await _database.db.query('profiles', orderBy: 'created_at');
    return rows.map(Profile.fromDbMap).toList();
  }

  Future<Profile?> getById(String id) async {
    final rows = await _database.db
        .query('profiles', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Profile.fromDbMap(rows.first);
  }

  /// Creates a new profile. The input must already be validated.
  Future<Profile> create({
    required String nickname,
    required String avatar,
    DietPreference diet = DietPreference.none,
  }) async {
    final now = DateTime.now();
    final profile = Profile(
      id: _newId(),
      nickname: nickname,
      avatar: avatar,
      diet: diet,
      createdAt: now,
      updatedAt: now,
    );
    await _database.db.insert('profiles', profile.toDbMap());
    await _syncQueue.enqueue(profile.id);
    notifyChanged(profile.id);
    return profile;
  }

  Future<Profile> update(Profile profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now());
    await _database.db.update(
      'profiles',
      updated.toDbMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
    await _syncQueue.enqueue(profile.id);
    notifyChanged(profile.id);
    return updated;
  }

  /// Deletes the profile and (through ON DELETE CASCADE) all its data.
  Future<void> delete(String id) async {
    await _database.db.delete('profiles', where: 'id = ?', whereArgs: [id]);
    await _syncQueue.enqueue(id, operation: SyncOperation.delete);
    if (await getLastProfileId() == id) await setLastProfileId(null);
    notifyChanged(id);
  }

  Future<String?> getLastProfileId() async {
    final rows = await _database.db.query('app_settings',
        where: 'key = ?', whereArgs: [_lastProfileKey], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setLastProfileId(String? id) async {
    await _database.db.rawInsert(
      'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
      [_lastProfileKey, id],
    );
  }

  /// Random, unguessable id (128 bits as hex).
  String _newId() => List.generate(
          16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
}
