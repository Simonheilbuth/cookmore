import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../viewmodels/home_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../widgets/recipe_master_detail.dart';
import '../widgets/recipe_widgets.dart';
import '../widgets/state_views.dart';
import 'recipe_detail_screen.dart';

/// Home: browse recipes by theme (category or cuisine) or search by name.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final profile = context.read<SessionViewModel>().current!;
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(services.recipes, profile.diet)..init(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _surpriseMe(HomeViewModel vm) async {
    final recipe = await vm.surpriseMe();
    if (!mounted) return;
    if (recipe == null) {
      showSnack(context, "Couldn't load a random recipe right now.");
      return;
    }
    RecipeDetailScreen.open(context, recipe.id, recipe: recipe);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CookMore'),
        actions: [
          IconButton(
            tooltip: 'Surprise me',
            onPressed: () => _surpriseMe(vm),
            icon: const Icon(Icons.casino_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              decoration: InputDecoration(
                hintText: 'Search recipes…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: vm.isSearching
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          vm.clearSearch();
                        },
                      )
                    : null,
              ),
              onSubmitted: vm.search,
            ),
          ),
          if (vm.diet.filtersResults)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${vm.diet.label.toLowerCase()} recipes only',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (!vm.isSearching) ...[
            _ThemeRow(
              title: 'Themes',
              kind: ThemeKind.category,
              names: vm.categories,
            ),
            _ThemeRow(
              title: 'Cuisines',
              kind: ThemeKind.area,
              names: vm.areas,
            ),
          ],
          if (vm.isOffline)
            OfflineBanner(
              message: "You're offline – showing recently viewed recipes.",
              onRetry: vm.retry,
            ),
          Expanded(child: _buildContent(vm)),
        ],
      ),
    );
  }

  Widget _buildContent(HomeViewModel vm) {
    if (vm.isLoading) return const LoadingView();
    if (vm.errorMessage != null) {
      return MessageView(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: vm.errorMessage,
        actionLabel: 'Try again',
        onAction: vm.retry,
      );
    }
    if (vm.recipes.isEmpty) {
      return MessageView(
        icon: Icons.search_off,
        title: vm.isOffline ? 'No saved recipes yet' : 'No recipes found',
        message: vm.isOffline
            ? 'Recipes you open are saved for offline reading.'
            : 'Try another theme or search word.',
      );
    }
    return RecipeMasterDetail(
      listBuilder: (context, onOpen, selectedId) => RecipeGrid(
        recipes: vm.recipes,
        onOpen: onOpen,
        selectedId: selectedId,
      ),
    );
  }
}

/// A horizontally scrolling row of theme chips.
class _ThemeRow extends StatefulWidget {
  const _ThemeRow({
    required this.title,
    required this.kind,
    required this.names,
  });

  final String title;
  final ThemeKind kind;
  final List<String> names;

  @override
  State<_ThemeRow> createState() => _ThemeRowState();
}

class _ThemeRowState extends State<_ThemeRow> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// On desktop, a normal (vertical) mouse wheel scrolls the row sideways.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    final delta =
        event.scrollDelta.dy != 0 ? event.scrollDelta.dy : event.scrollDelta.dx;
    if (delta == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final position = _scroll.position;
      _scroll.jumpTo((position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final kind = widget.kind;
    final names = widget.names;
    if (names.isEmpty) return const SizedBox.shrink();
    final vm = context.watch<HomeViewModel>();
    return SizedBox(
      height: 48,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: names.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Center(
                child:
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
              );
            }
            final theme = RecipeTheme(kind, names[index - 1]);
            return ChoiceChip(
              label: Text(theme.name),
              selected: vm.selectedTheme == theme,
              onSelected: (_) => vm.selectTheme(theme),
            );
          },
        ),
      ),
    );
  }
}
