import '../models/recipe.dart';

/// A recipe found by an ingredient search, with the searched ingredients
/// it contains.
class RecipeMatch {
  const RecipeMatch({required this.recipe, required this.matchedIngredients});

  final RecipeSummary recipe;
  final List<String> matchedIngredients;

  int get matchCount => matchedIngredients.length;
}

/// Which of a recipe's ingredients the user has and which are missing.
class IngredientCoverage {
  const IngredientCoverage({required this.available, required this.missing});

  final List<RecipeIngredient> available;
  final List<RecipeIngredient> missing;

  int get total => available.length + missing.length;
}

/// Pure Dart logic for matching recipes against ingredients.
///
/// This class has no Flutter, network or database dependencies, so it can
/// be unit tested in isolation (see test/recipe_matcher_test.dart).
class RecipeMatcher {
  const RecipeMatcher();

  /// Lower-cases the text, turns "_" and "-" into spaces and removes
  /// repeated whitespace. "Chicken_Breast " becomes "chicken breast".
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Combines one result list per searched ingredient into a ranked list.
  ///
  /// TheMealDB's free API can only filter by one ingredient at a time, so
  /// the app searches each ingredient separately and this method counts how
  /// many of the searched ingredients each recipe appears under.
  ///
  /// Recipes with the most matches come first. Ties are sorted by name.
  List<RecipeMatch> rank(Map<String, List<RecipeSummary>> recipesByIngredient) {
    final recipes = <String, RecipeSummary>{};
    final matched = <String, List<String>>{};

    recipesByIngredient.forEach((ingredient, results) {
      final seenForThisIngredient = <String>{};
      for (final recipe in results) {
        // Ignore duplicates inside the same result list.
        if (!seenForThisIngredient.add(recipe.id)) continue;
        recipes.putIfAbsent(recipe.id, () => recipe);
        matched.putIfAbsent(recipe.id, () => []).add(ingredient);
      }
    });

    final ranked = [
      for (final entry in recipes.entries)
        RecipeMatch(
          recipe: entry.value,
          matchedIngredients: List.unmodifiable(matched[entry.key]!),
        ),
    ];

    ranked.sort((a, b) {
      final byCount = b.matchCount.compareTo(a.matchCount);
      if (byCount != 0) return byCount;
      return a.recipe.name.toLowerCase().compareTo(b.recipe.name.toLowerCase());
    });
    return ranked;
  }

  /// True if [recipeIngredient] is covered by one of the [available]
  /// ingredients.
  ///
  /// A match means every word of the available ingredient appears in the
  /// recipe ingredient, ignoring case and simple plurals. So "chicken"
  /// covers "Chicken Breast", and "egg" covers "Eggs".
  bool isAvailable(String recipeIngredient, Iterable<String> available) {
    final recipeWords = _words(recipeIngredient);
    if (recipeWords.isEmpty) return false;
    for (final item in available) {
      final itemWords = _words(item);
      if (itemWords.isNotEmpty && recipeWords.containsAll(itemWords)) {
        return true;
      }
    }
    return false;
  }

  /// Splits a recipe's ingredients into the ones the user has and the ones
  /// that are missing.
  IngredientCoverage coverage(
    List<RecipeIngredient> ingredients,
    Iterable<String> available,
  ) {
    final have = <RecipeIngredient>[];
    final missing = <RecipeIngredient>[];
    final availableList = available.toList();
    for (final ingredient in ingredients) {
      if (isAvailable(ingredient.name, availableList)) {
        have.add(ingredient);
      } else {
        missing.add(ingredient);
      }
    }
    return IngredientCoverage(available: have, missing: missing);
  }

  Set<String> _words(String value) => normalize(value)
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(_singular)
      .toSet();

  /// Very small English singulariser: "tomatoes" -> "tomato",
  /// "eggs" -> "egg". Words ending in "ss" (e.g. "glass") are kept.
  String _singular(String word) {
    if (word.length > 3 && word.endsWith('oes')) {
      return word.substring(0, word.length - 2);
    }
    if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }
}
