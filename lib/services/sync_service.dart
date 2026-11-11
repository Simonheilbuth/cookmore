import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/favourites_repository.dart';
import '../repositories/pantry_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/shopping_list_repository.dart';
import 'cloud_backup_service.dart';
import 'connectivity_service.dart';
import 'sync_queue.dart';

/// Uploads queued local changes to the cloud when the device is online.
///
/// Strategy (kept simple on purpose):
/// 1. Every change is written to SQLite first and queued in `pending_sync`.
/// 2. When online, a full snapshot of each queued profile is uploaded.
/// 3. The newest upload wins ("last write wins").
/// If an upload fails, the item stays in the queue and is retried later.
class SyncService extends ChangeNotifier {
  SyncService({
    required SyncQueue queue,
    required CloudBackupService cloud,
    required ConnectivityService connectivity,
    required ProfileRepository profiles,
    required FavouritesRepository favourites,
    required PantryRepository pantry,
    required ShoppingListRepository shoppingList,
  })  : _queue = queue,
        _cloud = cloud,
        _connectivity = connectivity,
        _profiles = profiles,
        _favourites = favourites,
        _pantry = pantry,
        _shoppingList = shoppingList;

  final SyncQueue _queue;
  final CloudBackupService _cloud;
  final ConnectivityService _connectivity;
  final ProfileRepository _profiles;
  final FavouritesRepository _favourites;
  final PantryRepository _pantry;
  final ShoppingListRepository _shoppingList;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  bool _isSyncing = false;
  bool _syncAgain = false;
  int _pendingCount = 0;
  DateTime? _lastSyncedAt;
  bool _lastAttemptFailed = false;

  bool get isConfigured => _cloud.isConfigured;
  String? get setupProblem => _cloud.setupProblem;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get lastAttemptFailed => _lastAttemptFailed;

  /// Starts listening for local changes and for the device coming online.
  void start() {
    _subscriptions.add(_queue.changes.listen((_) => syncNow()));
    _subscriptions.add(_connectivity.onlineChanges.listen((online) {
      if (online) syncNow();
    }));
    syncNow();
  }

  /// Tries to upload everything in the queue.
  Future<void> syncNow() async {
    if (_isSyncing) {
      // A sync is running; run once more afterwards to pick up new changes.
      _syncAgain = true;
      return;
    }
    _isSyncing = true;
    notifyListeners();

    try {
      do {
        _syncAgain = false;
        await _pushPending();
      } while (_syncAgain);
    } finally {
      _isSyncing = false;
      _pendingCount = await _queue.count();
      notifyListeners();
    }
  }

  Future<void> _pushPending() async {
    _pendingCount = await _queue.count();
    if (!_cloud.isConfigured || _pendingCount == 0) return;
    if (!await _connectivity.isOnline()) return;

    var failed = false;
    for (final item in await _queue.pending()) {
      final startedAt = DateTime.now().millisecondsSinceEpoch;
      try {
        if (item.operation == SyncOperation.delete) {
          await _cloud.deleteProfile(item.profileId);
        } else {
          final snapshot = await _buildSnapshot(item.profileId);
          if (snapshot != null) {
            await _cloud.uploadProfile(item.profileId, snapshot);
          }
        }
        await _queue.complete(item, startedAt: startedAt);
      } catch (error) {
        // Keep the item in the queue and try again later.
        debugPrint('SyncService: upload failed: $error');
        failed = true;
        break;
      }
    }
    _lastAttemptFailed = failed;
    if (!failed) _lastSyncedAt = DateTime.now();
  }

  /// Everything the cloud backup contains for one profile.
  /// Only non-sensitive data: nickname, avatar, preferences and lists.
  Future<Map<String, Object?>?> _buildSnapshot(String profileId) async {
    final profile = await _profiles.getById(profileId);
    if (profile == null) return null;
    final shopping = await _shoppingList.getAll(profileId);
    return {
      'nickname': profile.nickname,
      'avatar': profile.avatar,
      'diet': profile.diet.name,
      'themeMode': profile.themePreference.name,
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': profile.updatedAt.toIso8601String(),
      'favourites': await _favourites.getCloudSnapshot(profileId),
      'pantry': await _pantry.getAll(profileId),
      'shoppingList': shopping.map((item) => item.toCloudMap()).toList(),
    };
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
