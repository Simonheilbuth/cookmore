import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../repositories/favourites_repository.dart';
import '../repositories/pantry_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/shopping_list_repository.dart';
import '../services/meal_db_api.dart';
import '../services/recipe_matcher.dart';

/// State for one recipe's detail view.
class RecipeDetailViewModel extends ChangeNotifier {
  RecipeDetailViewModel({
    required this.recipeId,
    required String profileId,
    required RecipeRepository recipes,
    required FavouritesRepository favourites,
    required PantryRepository pantry,
    required ShoppingListRepository shoppingList,
    required RecipeMatcher matcher,
    Recipe? initialRecipe,
  })  : _profileId = profileId,
        _recipes = recipes,
        _favourites = favourites,
        _pantry = pantry,
        _shoppingList = shoppingList,
        _matcher = matcher,
        recipe = initialRecipe {
    // Update the ingredient check marks when the pantry changes.
    _pantrySubscription = _pantry.changes
        .where((id) => id == _profileId)
        .listen((_) => _loadPantry());
  }

  final String recipeId;
  final String _profileId;
  final RecipeRepository _recipes;
  final FavouritesRepository _favourites;
  final PantryRepository _pantry;
  final ShoppingListRepository _shoppingList;
  final RecipeMatcher _matcher;
  late final StreamSubscription<String> _pantrySubscription;

  Recipe? recipe;
  bool isLoading = false;
  bool isFavourite = false;
  String? errorMessage;
  List<String> _pantryItems = [];

  bool get hasPantry => _pantryItems.isNotEmpty;

  /// Which ingredients the user has (based on the pantry).
  IngredientCoverage? get coverage {
    final current = recipe;
    if (current == null || !hasPantry) return null;
    return _matcher.coverage(current.ingredients, _pantryItems);
  }

  Future<void> load() async {
    isLoading = recipe == null;
    errorMessage = null;
    notifyListeners();
    try {
      recipe ??= await _recipes.getRecipe(recipeId);
      if (recipe == null) {
        errorMessage = 'This recipe could not be found.';
      }
    } on ApiException catch (error) {
      errorMessage = error is OfflineException
          ? "You're offline and this recipe isn't saved on your device."
          : error.message;
    }
    isFavourite = await _favourites.isFavourite(_profileId, recipeId);
    await _loadPantry(notify: false);
    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleFavourite() async {
    final current = recipe;
    if (current == null) return;
    if (isFavourite) {
      await _favourites.remove(_profileId, current.id);
    } else {
      await _favourites.add(_profileId, current);
    }
    isFavourite = !isFavourite;
    notifyListeners();
  }

  /// Adds the missing ingredients (or all, if the pantry is empty) to the
  /// shopping list. Returns how many items were added.
  Future<int> addMissingToShoppingList() async {
    final current = recipe;
    if (current == null) return 0;
    final items = coverage?.missing ?? current.ingredients;
    return _shoppingList.addAll(
      _profileId,
      items
          .map((ingredient) => ShoppingItem(
                name: ingredient.name,
                measure: ingredient.measure,
                recipeName: current.name,
              ))
          .toList(),
    );
  }

  Future<void> _loadPantry({bool notify = true}) async {
    _pantryItems = await _pantry.getAll(_profileId);
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _pantrySubscription.cancel();
    super.dispose();
  }
}
