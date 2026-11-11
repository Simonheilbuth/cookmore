import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_services.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/shopping_list_view_model.dart';
import '../widgets/ingredient_input.dart';
import '../widgets/state_views.dart';

/// Shopping list. Items can be checked off, swiped away and shared.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final profile = context.read<SessionViewModel>().current!;
    return ChangeNotifierProvider(
      create: (_) =>
          ShoppingListViewModel(services.shoppingList, profile.id)..load(),
      child: const _ShoppingListView(),
    );
  }
}

class _ShoppingListView extends StatelessWidget {
  const _ShoppingListView();

  Future<void> _share(BuildContext context, ShoppingListViewModel vm) async {
    try {
      // Opens the native share sheet (messages, e-mail, notes, ...).
      await SharePlus.instance.share(
        ShareParams(text: vm.shareText, subject: 'Shopping list'),
      );
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Sharing is not available on this device.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingListViewModel>();
    final hasOpenItems = vm.items.any((item) => !item.checked);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping list'),
        actions: [
          IconButton(
            tooltip: 'Remove checked items',
            onPressed: vm.hasChecked ? vm.clearChecked : null,
            icon: const Icon(Icons.remove_done),
          ),
          IconButton(
            tooltip: 'Share list',
            onPressed: hasOpenItems ? () => _share(context, vm) : null,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      // On wide screens the list is kept at a readable width.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: IngredientInput(
                  hintText: 'Add an item',
                  errorText: vm.inputError,
                  onSubmit: vm.addItem,
                ),
              ),
              Expanded(child: _buildList(context, vm)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, ShoppingListViewModel vm) {
    if (vm.isLoading) return const LoadingView();
    if (vm.items.isEmpty) {
      return const MessageView(
        icon: Icons.shopping_cart_outlined,
        title: 'Your shopping list is empty',
        message: 'Add items here, or tap "Add missing to shopping list" '
            'on a recipe.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: vm.items.length,
      itemBuilder: (context, index) {
        final item = vm.items[index];
        // Swipe left to delete.
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: scheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.delete, color: scheme.onErrorContainer),
          ),
          onDismissed: (_) {
            vm.remove(item);
            showSnack(context, 'Removed ${item.name}');
          },
          child: CheckboxListTile(
            value: item.checked,
            onChanged: (_) => vm.toggle(item),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              item.displayText,
              style: item.checked
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle:
                item.recipeName == null ? null : Text('For ${item.recipeName}'),
          ),
        );
      },
    );
  }
}
