import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../layout/breakpoints.dart';
import '../screens/recipe_detail_screen.dart';
import 'state_views.dart';

/// Builds the recipe list. [onOpen] must be called when a recipe is tapped.
typedef RecipeListBuilder = Widget Function(
  BuildContext context,
  ValueChanged<RecipeSummary> onOpen,
  String? selectedId,
);

/// Adaptive list–detail layout.
///
/// - Narrow (< 840 dp): only the list is shown; tapping a recipe opens a
///   new detail screen.
/// - Wide (>= 840 dp): the list is on the left and the selected recipe is
///   shown on the right, without leaving the screen.
class RecipeMasterDetail extends StatefulWidget {
  const RecipeMasterDetail({super.key, required this.listBuilder});

  final RecipeListBuilder listBuilder;

  @override
  State<RecipeMasterDetail> createState() => _RecipeMasterDetailState();
}

class _RecipeMasterDetailState extends State<RecipeMasterDetail> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.expanded;

        if (!isWide) {
          return widget.listBuilder(
            context,
            (recipe) => RecipeDetailScreen.open(context, recipe.id),
            null,
          );
        }

        final selectedId = _selectedId;
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: widget.listBuilder(
                context,
                (recipe) => setState(() => _selectedId = recipe.id),
                selectedId,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: 5,
              child: selectedId == null
                  ? const MessageView(
                      icon: Icons.menu_book_outlined,
                      title: 'No recipe selected',
                      message: 'Pick a recipe from the list to see it here.',
                    )
                  : RecipeDetailView(
                      key: ValueKey(selectedId),
                      recipeId: selectedId,
                    ),
            ),
          ],
        );
      },
    );
  }
}
