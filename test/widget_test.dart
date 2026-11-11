import 'package:cookmore/models/recipe.dart';
import 'package:cookmore/ui/widgets/recipe_widgets.dart';
import 'package:cookmore/ui/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MessageView shows title, message and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageView(
          icon: Icons.search_off,
          title: 'No recipes found',
          message: 'Try another theme.',
          actionLabel: 'Try again',
          onAction: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('No recipes found'), findsOneWidget);
    expect(find.text('Try another theme.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(tapped, isTrue);
  });

  testWidgets('RecipeGrid uses 1 column on a phone and more on a tablet',
      (tester) async {
    expect(RecipeGrid.columnsFor(390), 1);
    expect(RecipeGrid.columnsFor(600), 2);
    expect(RecipeGrid.columnsFor(1100), 4);

    final recipes = [
      for (var i = 0; i < 3; i++) RecipeSummary(id: '$i', name: 'Recipe $i'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RecipeGrid(recipes: recipes, onOpen: (_) {})),
    ));
    expect(find.text('Recipe 0'), findsOneWidget);
  });
}
