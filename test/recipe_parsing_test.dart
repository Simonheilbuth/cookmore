import 'package:cookmore/models/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final validJson = <String, Object?>{
    'idMeal': '52772',
    'strMeal': ' Teriyaki Chicken Casserole ',
    'strCategory': 'Chicken',
    'strArea': 'Japanese',
    'strInstructions': 'STEP 1\r\nPreheat oven.\r\n\r\nSTEP 2\r\nMix the sauce.',
    'strMealThumb': 'https://www.themealdb.com/images/media/meals/abc.jpg',
    'strTags': 'Meat,Casserole',
    'strIngredient1': 'soy sauce',
    'strMeasure1': '3/4 cup',
    'strIngredient2': '',
    'strMeasure2': '',
    'strIngredient3': null,
    'strIngredient4': 'chicken breasts',
    'strMeasure4': '2',
  };

  test('parses a valid meal and skips empty ingredient slots', () {
    final recipe = Recipe.tryFromJson(validJson)!;

    expect(recipe.id, '52772');
    expect(recipe.name, 'Teriyaki Chicken Casserole');
    expect(recipe.ingredients.map((i) => i.name),
        ['soy sauce', 'chicken breasts']);
    expect(recipe.tags, ['Meat', 'Casserole']);
  });

  test('splits instructions into steps without STEP headings', () {
    final recipe = Recipe.tryFromJson(validJson)!;
    expect(recipe.steps, ['Preheat oven.', 'Mix the sauce.']);
  });

  test('round-trips through toJson (used for the offline cache)', () {
    final recipe = Recipe.tryFromJson(validJson)!;
    final copy = Recipe.tryFromJson(recipe.toJson())!;

    expect(copy.name, recipe.name);
    expect(copy.ingredients.length, recipe.ingredients.length);
    expect(copy.thumbnailUrl, recipe.thumbnailUrl);
  });

  test('rejects invalid data from the API', () {
    expect(Recipe.tryFromJson(null), isNull);
    expect(Recipe.tryFromJson('not a map'), isNull);
    expect(Recipe.tryFromJson({'idMeal': '1'}), isNull);
    expect(Recipe.tryFromJson({'idMeal': 'abc', 'strMeal': 'X'}), isNull);
  });

  test('ignores image URLs that are not HTTPS', () {
    final summary = RecipeSummary.tryFromJson({
      'idMeal': '1',
      'strMeal': 'Soup',
      'strMealThumb': 'http://example.com/soup.jpg',
    })!;
    expect(summary.thumbnailUrl, isNull);
  });
}
