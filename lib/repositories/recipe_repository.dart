import 'dart:convert';

import '../config/app_config.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import '../services/local_database.dart';
import '../services/meal_db_api.dart';
import '../services/recipe_matcher.dart';
import 'favourites_repository.dart';

/// Single entry point for recipe data.
///
/// Combines the online API with an in-memory cache (to save network calls)
/// and the local `recipe_cache` table (so recently viewed recipes can be
/// read offline).
class RecipeRepository {
  RecipeRepository(
    this._api,
    this._database,
    this._favourites, {
    RecipeMatcher matcher = const RecipeMatcher(),
  }) : _matcher = matcher;

  final MealDbApi _api;
  final LocalDatabase _database;
  final FavouritesRepository _favourites;
  final RecipeMatcher _matcher;

  List<String>? _categories;
  List<String>? _areas;

  /// Cached filter results, e.g. "c:Dessert" -> recipes.
  final Map<String, List<RecipeSummary>> _filterCache = {};

  Future<List<String>> getCategories() async =>
      _categories ??= await _api.fetchCategories();

  Future<List<String>> getAreas() async =>
      _areas ??= await _api.fetchAreas();

  Future<List<RecipeSummary>> getByCategory(String category) =>
      _cached('c:$category', () => _api.filterByCategory(category));

  Future<List<RecipeSummary>> getByArea(String area) =>
      _cached('a:$area', () => _api.filterByArea(area));

  Future<List<RecipeSummary>> searchByName(String query) =>
      _api.searchByName(query);

  /// Removes recipes that do not fit the profile's diet.
  ///
  /// TheMealDB has "Vegetarian" and "Vegan" categories, so the allowed
  /// recipe ids are fetched once per category and used as a filter.
  Future<List<RecipeSummary>> applyDiet(
    List<RecipeSummary> recipes,
    DietPreference diet,
  ) async {
    if (!diet.filtersResults) return recipes;
    final allowedIds = <String>{};
    for (final category in diet.allowedCategories) {
      allowedIds.addAll((await getByCategory(category)).map((r) => r.id));
    }
    return recipes.where((r) => allowedIds.contains(r.id)).toList();
  }

  /// "What can I cook?": searches every ingredient in parallel, then ranks
  /// the recipes by how many of the ingredients they contain.
  Future<List<RecipeMatch>> findByIngredients(
    List<String> ingredients, {
    DietPreference diet = DietPreference.none,
  }) async {
    final unique = <String, String>{};
    for (final ingredient in ingredients) {
      unique.putIfAbsent(RecipeMatcher.normalize(ingredient), () => ingredient);
    }
    final searchList =
        unique.values.take(AppConfig.maxSearchIngredients).toList();

    final results = await Future.wait(searchList.map((ingredient) =>
        _cached('i:${RecipeMatcher.normalize(ingredient)}',
            () => _api.filterByIngredient(ingredient))));

    final byIngredient = <String, List<RecipeSummary>>{
      for (var i = 0; i < searchList.length; i++) searchList[i]: results[i],
    };

    var matches = _matcher.rank(byIngredient);
    if (diet.filtersResults) {
      final allowed = (await applyDiet(
        matches.map((m) => m.recipe).toList(),
        diet,
      ))
          .map((r) => r.id)
          .toSet();
      matches = matches.where((m) => allowed.contains(m.recipe.id)).toList();
    }
    return matches;
  }

  /// Full recipe by id.
  ///
  /// Recipes rarely change, so local copies are used first (cache-first).
  /// This makes the detail screen fast and lets it work offline.
  Future<Recipe?> getRecipe(String id) async {
    final local = await _readFromCache(id) ?? await _favourites.findSavedCopy(id);
    if (local != null) return local;

    final recipe = await _api.lookupRecipe(id);
    if (recipe != null) await _writeToCache(recipe);
    return recipe;
  }

  Future<Recipe?> getRandomRecipe() async {
    final recipe = await _api.randomRecipe();
    if (recipe != null) await _writeToCache(recipe);
    return recipe;
  }

  /// Recently viewed recipes, used when the device is offline.
  Future<List<RecipeSummary>> getRecentlyViewed() async {
    final rows = await _database.db.query(
      'recipe_cache',
      orderBy: 'cached_at DESC',
      limit: AppConfig.recipeCacheLimit,
    );
    return rows
        .map((row) => _decode(row['recipe_json'] as String)?.summary)
        .whereType<RecipeSummary>()
        .toList();
  }

  Future<List<RecipeSummary>> _cached(
    String key,
    Future<List<RecipeSummary>> Function() load,
  ) async {
    final hit = _filterCache[key];
    if (hit != null) return hit;
    final result = await load();
    _filterCache[key] = result;
    return result;
  }

  Future<Recipe?> _readFromCache(String id) async {
    final rows = await _database.db.query(
      'recipe_cache',
      where: 'recipe_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first['recipe_json'] as String);
  }

  Future<void> _writeToCache(Recipe recipe) async {
    final db = _database.db;
    await db.rawInsert(
      'INSERT OR REPLACE INTO recipe_cache (recipe_id, recipe_json, cached_at) '
      'VALUES (?, ?, ?)',
      [recipe.id, jsonEncode(recipe.toJson()), DateTime.now().millisecondsSinceEpoch],
    );
    // Keep only the newest entries.
    await db.rawDelete(
      'DELETE FROM recipe_cache WHERE recipe_id NOT IN '
      '(SELECT recipe_id FROM recipe_cache ORDER BY cached_at DESC LIMIT ?)',
      [AppConfig.recipeCacheLimit],
    );
  }

  Recipe? _decode(String text) {
    try {
      return Recipe.tryFromJson(jsonDecode(text));
    } on FormatException {
      return null;
    }
  }
}
