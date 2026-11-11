import 'dart:async';

import 'local_database.dart';

/// What has to happen to a profile in the cloud.
enum SyncOperation { upsert, delete }

/// A profile waiting to be synced.
class PendingSync {
  const PendingSync(this.profileId, this.operation);

  final String profileId;
  final SyncOperation operation;
}

/// Local queue of profiles that changed while (possibly) offline.
///
/// Repositories call [enqueue] after every local write. The queue is stored
/// in the `pending_sync` table, so changes survive an app restart and are
/// uploaded by the SyncService when the device is online.
class SyncQueue {
  SyncQueue(this._database);

  final LocalDatabase _database;
  final StreamController<void> _changes = StreamController.broadcast();

  /// Emits whenever something new is queued.
  Stream<void> get changes => _changes.stream;

  Future<void> enqueue(
    String profileId, {
    SyncOperation operation = SyncOperation.upsert,
  }) async {
    // One row per profile: a newer change replaces an older one.
    await _database.db.rawInsert(
      'INSERT OR REPLACE INTO pending_sync (profile_id, operation, queued_at) '
      'VALUES (?, ?, ?)',
      [profileId, operation.name, DateTime.now().millisecondsSinceEpoch],
    );
    _changes.add(null);
  }

  Future<List<PendingSync>> pending() async {
    final rows = await _database.db.query('pending_sync', orderBy: 'queued_at');
    return rows
        .map((row) => PendingSync(
              row['profile_id'] as String,
              row['operation'] == SyncOperation.delete.name
                  ? SyncOperation.delete
                  : SyncOperation.upsert,
            ))
        .toList();
  }

  Future<int> count() async {
    final rows =
        await _database.db.rawQuery('SELECT COUNT(*) AS c FROM pending_sync');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Removes a profile from the queue once it has been synced, but only if
  /// it has not been queued again in the meantime.
  Future<void> complete(PendingSync item, {required int startedAt}) async {
    await _database.db.delete(
      'pending_sync',
      where: 'profile_id = ? AND queued_at <= ?',
      whereArgs: [item.profileId, startedAt],
    );
  }

  void dispose() => _changes.close();
}
