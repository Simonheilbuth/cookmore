import '../services/local_database.dart';
import '../services/sync_queue.dart';
import 'change_notifying_repository.dart';

/// Ingredients the user has at home ("My pantry").
class PantryRepository with ChangeNotifyingRepository {
  PantryRepository(this._database, this._syncQueue);

  final LocalDatabase _database;
  final SyncQueue _syncQueue;

  Future<List<String>> getAll(String profileId) async {
    final rows = await _database.db.query(
      'pantry_items',
      columns: ['name'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  /// Adds an ingredient. The name must already be validated.
  /// Names are stored in lower case so duplicates are ignored.
  Future<void> add(String profileId, String name) async {
    await _database.db.rawInsert(
      'INSERT OR IGNORE INTO pantry_items (profile_id, name) VALUES (?, ?)',
      [profileId, name.toLowerCase()],
    );
    await _syncQueue.enqueue(profileId);
    notifyChanged(profileId);
  }

  Future<void> remove(String profileId, String name) async {
    await _database.db.delete(
      'pantry_items',
      where: 'profile_id = ? AND name = ?',
      whereArgs: [profileId, name],
    );
    await _syncQueue.enqueue(profileId);
    notifyChanged(profileId);
  }
}
