import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_services.dart';
import '../../models/recipe.dart';
import '../../viewmodels/recipe_detail_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../widgets/cooking_timer_card.dart';
import '../widgets/recipe_widgets.dart';
import '../widgets/state_views.dart';

/// Full-screen recipe page, used on narrow screens.
class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipeId, this.recipe});

  final String recipeId;
  final Recipe? recipe;

  /// Opens the recipe as a new page. The recipe id is passed to the next
  /// screen; the full recipe can be passed too if it is already loaded.
  static Future<void> open(
    BuildContext context,
    String recipeId, {
    Recipe? recipe,
  }) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RecipeDetailScreen(recipeId: recipeId, recipe: recipe),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe')),
      body: RecipeDetailView(recipeId: recipeId, initialRecipe: recipe),
    );
  }
}

/// The recipe content. Used both as a full page and as the right-hand pane
/// of the list–detail layout on tablets and desktop.
class RecipeDetailView extends StatelessWidget {
  const RecipeDetailView({
    super.key,
    required this.recipeId,
    this.initialRecipe,
  });

  final String recipeId;
  final Recipe? initialRecipe;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final profile = context.read<SessionViewModel>().current!;
    return ChangeNotifierProvider(
      create: (_) => RecipeDetailViewModel(
        recipeId: recipeId,
        profileId: profile.id,
        recipes: services.recipes,
        favourites: services.favourites,
        pantry: services.pantry,
        shoppingList: services.shoppingList,
        matcher: services.matcher,
        initialRecipe: initialRecipe,
      )..load(),
      child: const _RecipeDetailBody(),
    );
  }
}

class _RecipeDetailBody extends StatelessWidget {
  const _RecipeDetailBody();

  Future<void> _share(BuildContext context, Recipe recipe) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: recipe.toShareText(), subject: recipe.name),
      );
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Sharing is not available on this device.');
      }
    }
  }

  Future<void> _addToShoppingList(
    BuildContext context,
    RecipeDetailViewModel vm,
  ) async {
    final added = await vm.addMissingToShoppingList();
    if (!context.mounted) return;
    showSnack(
      context,
      added == 0
          ? 'Everything is already on your shopping list.'
          : 'Added $added ${added == 1 ? 'item' : 'items'} to your shopping list.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecipeDetailViewModel>();
    final recipe = vm.recipe;

    if (vm.isLoading) return const LoadingView();
    if (recipe == null) {
      return MessageView(
        icon: Icons.cloud_off,
        title: 'Recipe not available',
        message: vm.errorMessage,
        actionLabel: 'Try again',
        onAction: vm.load,
      );
    }

    final theme = Theme.of(context);
    final coverage = vm.coverage;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: RecipeImage(url: recipe.thumbnailUrl),
          ),
        ),
        const SizedBox(height: 12),
        Text(recipe.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (recipe.category != null) Chip(label: Text(recipe.category!)),
            if (recipe.area != null) Chip(label: Text(recipe.area!)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: vm.toggleFavourite,
              icon: Icon(vm.isFavourite ? Icons.favorite : Icons.favorite_border),
              label: Text(vm.isFavourite ? 'Saved' : 'Save'),
            ),
            OutlinedButton.icon(
              onPressed: () => _share(context, recipe),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CookingTimerCard(label: recipe.name),
        const SizedBox(height: 16),
        Text('Ingredients', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          coverage == null
              ? 'Add items to "My pantry" on the Profile tab to see what you are missing.'
              : 'You have ${coverage.available.length}/${coverage.total} ingredients.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        for (final ingredient in recipe.ingredients)
          _IngredientRow(
            ingredient: ingredient,
            available: coverage?.available.contains(ingredient),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _addToShoppingList(context, vm),
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(coverage == null
                ? 'Add all to shopping list'
                : 'Add missing to shopping list'),
          ),
        ),
        const SizedBox(height: 20),
        Text('Instructions', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final (index, step) in recipe.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 13, child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Expanded(child: Text(step)),
              ],
            ),
          ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.available});

  final RecipeIngredient ingredient;

  /// null when the pantry is empty (no check marks are shown).
  final bool? available;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (available) {
      true => Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
      false => Icon(Icons.cancel_outlined, color: scheme.error, size: 20),
      null => Icon(Icons.circle, color: scheme.outline, size: 8),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 24, child: Center(child: icon)),
          const SizedBox(width: 8),
          Expanded(child: Text(ingredient.name)),
          Text(ingredient.measure,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
