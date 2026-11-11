import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import '../repositories/favourites_repository.dart';

/// State for the Favourites screen. Works fully offline.
class FavouritesViewModel extends ChangeNotifier {
  FavouritesViewModel(this._favourites, this._profileId) {
    // Reload when a favourite is added or removed anywhere in the app.
    _subscription = _favourites.changes
        .where((id) => id == _profileId)
        .listen((_) => load());
  }

  final FavouritesRepository _favourites;
  final String _profileId;
  late final StreamSubscription<String> _subscription;

  List<Recipe> favourites = [];
  bool isLoading = true;

  Future<void> load() async {
    favourites = await _favourites.getAll(_profileId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> remove(Recipe recipe) =>
      _favourites.remove(_profileId, recipe.id);

  Future<void> restore(Recipe recipe) => _favourites.add(_profileId, recipe);

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
