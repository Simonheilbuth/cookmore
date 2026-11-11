import 'dart:convert';

import '../models/recipe.dart';
import '../services/local_database.dart';
import '../services/sync_queue.dart';
import 'change_notifying_repository.dart';

/// A profile's favourite recipes. A full copy of each recipe is stored, so
/// favourites can be opened without an internet connection.
class FavouritesRepository with ChangeNotifyingRepository {
  FavouritesRepository(this._database, this._syncQueue);

  final LocalDatabase _database;
  final SyncQueue _syncQueue;

  Future<List<Recipe>> getAll(String profileId) async {
    final rows = await _database.db.query(
      'favourites',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'saved_at DESC',
    );
    return rows
        .map((row) => _decode(row['recipe_json'] as String))
        .whereType<Recipe>()
        .toList();
  }

  Future<bool> isFavourite(String profileId, String recipeId) async {
    final rows = await _database.db.query(
      'favourites',
      columns: ['recipe_id'],
      where: 'profile_id = ? AND recipe_id = ?',
      whereArgs: [profileId, recipeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Finds a saved copy of a recipe in any profile's favourites.
  Future<Recipe?> findSavedCopy(String recipeId) async {
    final rows = await _database.db.query(
      'favourites',
      columns: ['recipe_json'],
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first['recipe_json'] as String);
  }

  Future<void> add(String profileId, Recipe recipe) async {
    await _database.db.rawInsert(
      'INSERT OR REPLACE INTO favourites '
      '(profile_id, recipe_id, name, recipe_json, saved_at) VALUES (?, ?, ?, ?, ?)',
      [
        profileId,
        recipe.id,
        recipe.name,
        jsonEncode(recipe.toJson()),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
    await _syncQueue.enqueue(profileId);
    notifyChanged(profileId);
  }

  Future<void> remove(String profileId, String recipeId) async {
    await _database.db.delete(
      'favourites',
      where: 'profile_id = ? AND recipe_id = ?',
      whereArgs: [profileId, recipeId],
    );
    await _syncQueue.enqueue(profileId);
    notifyChanged(profileId);
  }

  /// Id and name of each favourite, used for the cloud backup.
  Future<List<Map<String, String>>> getCloudSnapshot(String profileId) async {
    final rows = await _database.db.query(
      'favourites',
      columns: ['recipe_id', 'name'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    return rows
        .map((row) => {
              'id': row['recipe_id'] as String,
              'name': row['name'] as String,
            })
        .toList();
  }

  Recipe? _decode(String text) {
    try {
      return Recipe.tryFromJson(jsonDecode(text));
    } on FormatException {
      return null;
    }
  }
}
