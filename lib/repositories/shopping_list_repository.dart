import '../models/shopping_item.dart';
import '../services/local_database.dart';
import '../services/sync_queue.dart';
import 'change_notifying_repository.dart';

/// The profile's shopping list.
class ShoppingListRepository with ChangeNotifyingRepository {
  ShoppingListRepository(this._database, this._syncQueue);

  final LocalDatabase _database;
  final SyncQueue _syncQueue;

  Future<List<ShoppingItem>> getAll(String profileId) async {
    final rows = await _database.db.query(
      'shopping_items',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'checked, id',
    );
    return rows.map(ShoppingItem.fromDbMap).toList();
  }

  /// Adds items, skipping names that are already on the unchecked list.
  /// Returns the number of items actually added.
  Future<int> addAll(String profileId, List<ShoppingItem> items) async {
    final existing = (await getAll(profileId))
        .where((item) => !item.checked)
        .map((item) => item.name.toLowerCase())
        .toSet();

    final batch = _database.db.batch();
    var added = 0;
    for (final item in items) {
      if (!existing.add(item.name.toLowerCase())) continue;
      batch.insert('shopping_items', item.toDbMap(profileId));
      added++;
    }
    if (added == 0) return 0;

    await batch.commit(noResult: true);
    await _syncQueue.enqueue(profileId);
    notifyChanged(profileId);
    return added;
  }

  Future<void> setChecked(String profileId, int itemId, bool checked) async {
    await _database.db.update(
      'shopping_items',
      {'checked': checked ? 1 : 0},
      where: 'id = ? AND profile_id = ?',
      whereArgs: [itemId, profileId],
    );
    await _syncQueue.enqueue(profileId);
    notifyChanged(profileId);
  }

  Future<void> remove(String profileId, int itemId) async {
    await _database.db.delete(
      'shopping_items',
      where: 'id = ? AND profile_id = ?',
      whereArgs: [itemId, profileId],
    );
    await _syncQueue.enqueue(profileId);
    notifyChanged(profileId);
  }

  Future<void> clearChecked(String profileId) async {
    await _database.db.delete(
      'shopping_items',
      where: 'profile_id = ? AND checked = 1',
      whereArgs: [profileId],
    );
    await _syncQueue.enqueue(profileId);
    notifyChanged(profileId);
  }
}
