import 'package:flutter/material.dart';

import '../../models/recipe.dart';

/// Recipe photo loaded over HTTPS, with a placeholder while loading or if
/// the image cannot be loaded (e.g. offline).
class RecipeImage extends StatelessWidget {
  const RecipeImage({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null) return const _ImagePlaceholder();
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _ImagePlaceholder(loading: true),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox.square(
              dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.restaurant, color: scheme.onSurfaceVariant),
    );
  }
}

/// A recipe card with image, name and an optional subtitle.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  final RecipeSummary recipe;
  final VoidCallback onTap;
  final String? subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: RecipeImage(url: recipe.thumbnailUrl)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive grid of recipe cards.
///
/// The number of columns follows the available width, so the same widget
/// shows 1 column on a phone, 2 in a tablet list pane and more on desktop.
class RecipeGrid extends StatelessWidget {
  const RecipeGrid({
    super.key,
    required this.recipes,
    required this.onOpen,
    this.selectedId,
    this.subtitleFor,
    this.header,
  });

  final List<RecipeSummary> recipes;
  final ValueChanged<RecipeSummary> onOpen;
  final String? selectedId;
  final String? Function(RecipeSummary recipe)? subtitleFor;
  final Widget? header;

  static int columnsFor(double width) {
    if (width < 440) return 1;
    return (width / 260).floor().clamp(2, 5);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        return CustomScrollView(
          slivers: [
            if (header != null) SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 1.6 : 0.95,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final recipe = recipes[index];
                    return RecipeCard(
                      recipe: recipe,
                      selected: recipe.id == selectedId,
                      subtitle: subtitleFor?.call(recipe),
                      onTap: () => onOpen(recipe),
                    );
                  },
                  childCount: recipes.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
