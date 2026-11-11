import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/profile.dart';
import '../repositories/pantry_repository.dart';
import '../repositories/recipe_repository.dart';
import '../services/meal_db_api.dart';
import '../services/recipe_matcher.dart';
import '../utils/validators.dart';

/// State for "What can I cook?" – search by ingredients.
class CookSearchViewModel extends ChangeNotifier {
  CookSearchViewModel(this._recipes, this._pantry, this._profile);

  final RecipeRepository _recipes;
  final PantryRepository _pantry;
  final Profile _profile;

  final List<String> _ingredients = [];
  List<RecipeMatch> results = [];
  bool isLoading = false;
  bool hasSearched = false;
  bool isOffline = false;

  /// Validation message shown under the input field.
  String? inputError;

  /// Error from the last search, safe to show to the user.
  String? errorMessage;

  List<String> get ingredients => List.unmodifiable(_ingredients);
  bool get canAddMore => _ingredients.length < AppConfig.maxSearchIngredients;
  bool get canSearch => _ingredients.isNotEmpty && !isLoading;

  /// Adds an ingredient chip. Returns true if it was added.
  bool addIngredient(String raw) {
    final error = Validators.ingredient(raw);
    if (error != null) {
      inputError = error;
      notifyListeners();
      return false;
    }
    if (!canAddMore) {
      inputError =
          'You can search with up to ${AppConfig.maxSearchIngredients} ingredients.';
      notifyListeners();
      return false;
    }
    final value = Validators.cleanIngredient(raw).toLowerCase();
    if (_ingredients.contains(value)) {
      inputError = '"$value" is already added.';
      notifyListeners();
      return false;
    }
    _ingredients.add(value);
    inputError = null;
    notifyListeners();
    return true;
  }

  void removeIngredient(String ingredient) {
    _ingredients.remove(ingredient);
    inputError = null;
    notifyListeners();
  }

  /// Fills free slots with ingredients from the pantry.
  /// Returns how many were added.
  Future<int> fillFromPantry() async {
    final pantry = await _pantry.getAll(_profile.id);
    var added = 0;
    for (final item in pantry) {
      if (!canAddMore) break;
      if (_ingredients.contains(item)) continue;
      _ingredients.add(item);
      added++;
    }
    inputError = null;
    notifyListeners();
    return added;
  }

  Future<void> search() async {
    if (!canSearch) return;
    isLoading = true;
    errorMessage = null;
    isOffline = false;
    notifyListeners();
    try {
      results = await _recipes.findByIngredients(
        _ingredients,
        diet: _profile.diet,
      );
    } on OfflineException {
      isOffline = true;
      results = [];
    } on ApiException catch (error) {
      errorMessage = error.message;
      results = [];
    }
    hasSearched = true;
    isLoading = false;
    notifyListeners();
  }
}
