import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../viewmodels/favourites_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../widgets/recipe_master_detail.dart';
import '../widgets/recipe_widgets.dart';
import '../widgets/state_views.dart';

/// The profile's saved recipes. Works without internet.
class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final profile = context.read<SessionViewModel>().current!;
    return ChangeNotifierProvider(
      create: (_) => FavouritesViewModel(services.favourites, profile.id)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Favourites')),
        body: Consumer<FavouritesViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) return const LoadingView();
            if (vm.favourites.isEmpty) {
              return const MessageView(
                icon: Icons.favorite_border,
                title: 'No favourites yet',
                message: 'Tap "Save" on a recipe to keep it here. '
                    'Favourites can also be opened offline.',
              );
            }
            return RecipeMasterDetail(
              listBuilder: (context, onOpen, selectedId) => RecipeGrid(
                recipes: vm.favourites.map((r) => r.summary).toList(),
                onOpen: onOpen,
                selectedId: selectedId,
              ),
            );
          },
        ),
      ),
    );
  }
}
