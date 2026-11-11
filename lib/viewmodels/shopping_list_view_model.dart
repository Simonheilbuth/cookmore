import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shopping_item.dart';
import '../repositories/shopping_list_repository.dart';
import '../utils/validators.dart';

/// State for the shopping list screen.
class ShoppingListViewModel extends ChangeNotifier {
  ShoppingListViewModel(this._repository, this._profileId) {
    _subscription = _repository.changes
        .where((id) => id == _profileId)
        .listen((_) => load());
  }

  final ShoppingListRepository _repository;
  final String _profileId;
  late final StreamSubscription<String> _subscription;

  List<ShoppingItem> items = [];
  bool isLoading = true;
  String? inputError;

  bool get hasChecked => items.any((item) => item.checked);

  Future<void> load() async {
    items = await _repository.getAll(_profileId);
    isLoading = false;
    notifyListeners();
  }

  /// Adds an item typed by the user. Returns true if it was added.
  Future<bool> addItem(String raw) async {
    final error = Validators.ingredient(raw);
    if (error != null) {
      inputError = error;
      notifyListeners();
      return false;
    }
    final added = await _repository.addAll(_profileId, [
      ShoppingItem(name: Validators.cleanIngredient(raw)),
    ]);
    inputError = added == 0 ? 'That item is already on the list.' : null;
    notifyListeners();
    return added > 0;
  }

  Future<void> toggle(ShoppingItem item) =>
      _repository.setChecked(_profileId, item.id!, !item.checked);

  /// Removes the item from the screen immediately (needed for swipe to
  /// delete), then from the database.
  Future<void> remove(ShoppingItem item) async {
    items = items.where((i) => i.id != item.id).toList();
    notifyListeners();
    await _repository.remove(_profileId, item.id!);
  }

  Future<void> clearChecked() => _repository.clearChecked(_profileId);

  /// Plain text for the share sheet (unchecked items only).
  String get shareText {
    final open = items.where((item) => !item.checked).toList();
    final buffer = StringBuffer('Shopping list\n\n');
    for (final item in open) {
      buffer.writeln('- ${item.displayText}');
    }
    buffer.writeln('\nShared from CookMore');
    return buffer.toString();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
