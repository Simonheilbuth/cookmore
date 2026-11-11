import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../config/app_config.dart';
import '../../services/recipe_matcher.dart';
import '../../viewmodels/cook_search_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../widgets/ingredient_input.dart';
import '../widgets/recipe_master_detail.dart';
import '../widgets/recipe_widgets.dart';
import '../widgets/state_views.dart';

/// "What can I cook?" – find recipes from the ingredients you have.
class CookScreen extends StatelessWidget {
  const CookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final profile = context.read<SessionViewModel>().current!;
    return ChangeNotifierProvider(
      create: (_) =>
          CookSearchViewModel(services.recipes, services.pantry, profile),
      child: const _CookView(),
    );
  }
}

class _CookView extends StatelessWidget {
  const _CookView();

  Future<void> _fillFromPantry(
    BuildContext context,
    CookSearchViewModel vm,
  ) async {
    final added = await vm.fillFromPantry();
    if (!context.mounted) return;
    if (added == 0) {
      showSnack(
        context,
        vm.canAddMore
            ? 'Nothing new in your pantry. Add items on the Profile tab.'
            : 'You already have ${AppConfig.maxSearchIngredients} ingredients.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CookSearchViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('What can I cook?')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: IngredientInput(
              hintText: 'Add an ingredient, e.g. chicken',
              errorText: vm.inputError,
              enabled: vm.canAddMore,
              onSubmit: vm.addIngredient,
            ),
          ),
          if (vm.ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ingredient in vm.ingredients)
                    InputChip(
                      label: Text(ingredient),
                      onDeleted: () => vm.removeIngredient(ingredient),
                      deleteButtonTooltipMessage: 'Remove $ingredient',
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _fillFromPantry(context, vm),
                  icon: const Icon(Icons.kitchen_outlined),
                  label: const Text('Fill from my pantry'),
                ),
                FilledButton.icon(
                  onPressed: vm.canSearch ? vm.search : null,
                  icon: const Icon(Icons.search),
                  label: Text(
                    'Find recipes (${vm.ingredients.length}/${AppConfig.maxSearchIngredients})',
                  ),
                ),
              ],
            ),
          ),
          if (vm.hasSearched && !vm.isLoading && vm.results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${vm.results.length} recipes – best matches first',
                style: theme.textTheme.titleSmall,
              ),
            ),
          Expanded(child: _buildResults(vm)),
        ],
      ),
    );
  }

  Widget _buildResults(CookSearchViewModel vm) {
    if (vm.isLoading) return const LoadingView();
    if (vm.isOffline) {
      return MessageView(
        icon: Icons.cloud_off,
        title: "You're offline",
        message: 'Searching needs an internet connection. '
            'Your favourites still work offline.',
        actionLabel: 'Try again',
        onAction: vm.search,
      );
    }
    if (vm.errorMessage != null) {
      return MessageView(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: vm.errorMessage,
        actionLabel: 'Try again',
        onAction: vm.search,
      );
    }
    if (!vm.hasSearched) {
      return const MessageView(
        icon: Icons.kitchen,
        title: "What's in your kitchen?",
        message: 'Add up to ${AppConfig.maxSearchIngredients} ingredients '
            'and tap "Find recipes".',
      );
    }
    if (vm.results.isEmpty) {
      return const MessageView(
        icon: Icons.search_off,
        title: 'No recipes found',
        message: 'Try fewer or more common ingredients.',
      );
    }

    final matchesById = <String, RecipeMatch>{
      for (final match in vm.results) match.recipe.id: match,
    };
    final total = vm.ingredients.length;

    return RecipeMasterDetail(
      listBuilder: (context, onOpen, selectedId) => RecipeGrid(
        recipes: vm.results.map((m) => m.recipe).toList(),
        onOpen: onOpen,
        selectedId: selectedId,
        subtitleFor: (recipe) {
          final match = matchesById[recipe.id];
          if (match == null) return null;
          return 'Matches ${match.matchCount}/$total: '
              '${match.matchedIngredients.join(', ')}';
        },
      ),
    );
  }
}
