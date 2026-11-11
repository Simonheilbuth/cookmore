import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../models/recipe.dart';
import '../repositories/recipe_repository.dart';
import '../services/meal_db_api.dart';

/// Which kind of theme a chip on the home screen represents.
enum ThemeKind { category, area }

/// A theme the user can browse, e.g. category "Dessert" or area "Italian".
class RecipeTheme {
  const RecipeTheme(this.kind, this.name);

  final ThemeKind kind;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is RecipeTheme && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);
}

/// State for the Home screen: theme browsing and search by name.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._recipes, this._diet);

  final RecipeRepository _recipes;
  final DietPreference _diet;

  List<String> categories = [];
  List<String> areas = [];
  RecipeTheme? selectedTheme;
  String query = '';

  List<RecipeSummary> recipes = [];
  bool isLoading = false;
  String? errorMessage;

  /// True when the last request failed because the device is offline.
  /// The list then shows recently viewed recipes instead.
  bool isOffline = false;

  DietPreference get diet => _diet;
  bool get isSearching => query.isNotEmpty;

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      categories = await _recipes.getCategories();
      areas = await _recipes.getAreas();
      // Start with the diet's category, otherwise "Chicken" (or the first).
      final preferred = _diet.filtersResults
          ? _diet.allowedCategories.first
          : 'Chicken';
      final start = categories.contains(preferred)
          ? preferred
          : (categories.isNotEmpty ? categories.first : null);
      if (start != null) {
        await selectTheme(RecipeTheme(ThemeKind.category, start));
        return;
      }
      isLoading = false;
      notifyListeners();
    } on ApiException catch (error) {
      await _handleError(error);
    }
  }

  Future<void> selectTheme(RecipeTheme theme) async {
    selectedTheme = theme;
    query = '';
    await _load(() => theme.kind == ThemeKind.category
        ? _recipes.getByCategory(theme.name)
        : _recipes.getByArea(theme.name));
  }

  Future<void> search(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }
    // Simple limit on the length of the search text.
    query = trimmed.length > 50 ? trimmed.substring(0, 50) : trimmed;
    await _load(() => _recipes.searchByName(query));
  }

  void clearSearch() {
    query = '';
    final theme = selectedTheme;
    if (theme != null) {
      selectTheme(theme);
    } else {
      init();
    }
  }

  Future<void> retry() {
    if (isSearching) return search(query);
    final theme = selectedTheme;
    return theme == null ? init() : selectTheme(theme);
  }

  Future<Recipe?> surpriseMe() async {
    try {
      return await _recipes.getRandomRecipe();
    } on ApiException {
      return null;
    }
  }

  Future<void> _load(Future<List<RecipeSummary>> Function() loader) async {
    isLoading = true;
    errorMessage = null;
    isOffline = false;
    notifyListeners();
    try {
      final result = await loader();
      recipes = await _recipes.applyDiet(result, _diet);
      isLoading = false;
      notifyListeners();
    } on ApiException catch (error) {
      await _handleError(error);
    }
  }

  Future<void> _handleError(ApiException error) async {
    isLoading = false;
    if (error is OfflineException) {
      isOffline = true;
      errorMessage = null;
      recipes = await _recipes.getRecentlyViewed();
    } else {
      errorMessage = error.message;
      recipes = [];
    }
    notifyListeners();
  }
}
