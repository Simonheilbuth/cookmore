import 'package:cookmore/models/recipe.dart';
import 'package:cookmore/services/recipe_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const matcher = RecipeMatcher();

  RecipeSummary recipe(String id, String name) =>
      RecipeSummary(id: id, name: name);

  group('normalize', () {
    test('lower-cases, trims and replaces underscores and hyphens', () {
      expect(RecipeMatcher.normalize('  Chicken_Breast '), 'chicken breast');
      expect(RecipeMatcher.normalize('Pak-Choi'), 'pak choi');
      expect(RecipeMatcher.normalize('red   onion'), 'red onion');
    });
  });

  group('rank', () {
    test('recipes with more matching ingredients come first', () {
      final ranked = matcher.rank({
        'chicken': [recipe('1', 'Chicken Curry'), recipe('2', 'Fried Rice')],
        'rice': [recipe('2', 'Fried Rice'), recipe('3', 'Rice Pudding')],
      });

      expect(ranked.first.recipe.id, '2');
      expect(ranked.first.matchCount, 2);
      expect(ranked.first.matchedIngredients, ['chicken', 'rice']);
      expect(ranked.length, 3);
    });

    test('ties are sorted alphabetically by name', () {
      final ranked = matcher.rank({
        'egg': [recipe('1', 'Omelette'), recipe('2', 'Carbonara')],
      });
      expect(ranked.map((m) => m.recipe.name), ['Carbonara', 'Omelette']);
    });

    test('duplicates inside one result list are counted once', () {
      final ranked = matcher.rank({
        'egg': [recipe('1', 'Omelette'), recipe('1', 'Omelette')],
      });
      expect(ranked.single.matchCount, 1);
    });

    test('no results gives an empty list', () {
      expect(matcher.rank({'chicken': [], 'rice': []}), isEmpty);
      expect(matcher.rank({}), isEmpty);
    });
  });

  group('isAvailable', () {
    test('ignores case and whitespace', () {
      expect(matcher.isAvailable('Chicken', [' chicken ']), isTrue);
    });

    test('a general ingredient covers a more specific one', () {
      expect(matcher.isAvailable('Chicken Breast', ['chicken']), isTrue);
    });

    test('a specific ingredient does not cover a general one', () {
      expect(matcher.isAvailable('Chicken', ['chicken breast']), isFalse);
    });

    test('handles simple plurals', () {
      expect(matcher.isAvailable('Eggs', ['egg']), isTrue);
      expect(matcher.isAvailable('Tomato', ['tomatoes']), isTrue);
    });

    test('unrelated ingredients do not match', () {
      expect(matcher.isAvailable('Beef', ['chicken', 'rice']), isFalse);
      expect(matcher.isAvailable('Beef', []), isFalse);
    });
  });

  group('coverage', () {
    test('splits ingredients into available and missing', () {
      const ingredients = [
        RecipeIngredient(name: 'Spaghetti', measure: '200g'),
        RecipeIngredient(name: 'Eggs', measure: '2'),
        RecipeIngredient(name: 'Pancetta', measure: '100g'),
      ];
      final result = matcher.coverage(ingredients, ['spaghetti', 'egg']);

      expect(result.available.map((i) => i.name), ['Spaghetti', 'Eggs']);
      expect(result.missing.map((i) => i.name), ['Pancetta']);
      expect(result.total, 3);
    });
  });
}
