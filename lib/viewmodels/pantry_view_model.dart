import 'package:flutter/foundation.dart';

import '../repositories/pantry_repository.dart';
import '../utils/validators.dart';

/// State for "My pantry" on the Profile screen.
class PantryViewModel extends ChangeNotifier {
  PantryViewModel(this._repository, this._profileId);

  final PantryRepository _repository;
  final String _profileId;

  static const int maxItems = 50;

  List<String> items = [];
  String? inputError;

  Future<void> load() async {
    items = await _repository.getAll(_profileId);
    notifyListeners();
  }

  /// Returns true if the item was added.
  Future<bool> add(String raw) async {
    final error = Validators.ingredient(raw);
    if (error != null) {
      inputError = error;
      notifyListeners();
      return false;
    }
    if (items.length >= maxItems) {
      inputError = 'Your pantry can hold up to $maxItems items.';
      notifyListeners();
      return false;
    }
    await _repository.add(_profileId, Validators.cleanIngredient(raw));
    inputError = null;
    await load();
    return true;
  }

  Future<void> remove(String item) async {
    await _repository.remove(_profileId, item);
    await load();
  }
}
