import 'dart:async';

/// Lets a repository tell listeners that the data of a profile has changed,
/// so screens showing the same data (e.g. favourites) can reload.
mixin ChangeNotifyingRepository {
  final StreamController<String> _changesController =
      StreamController.broadcast();

  /// Emits the profile id whose data changed.
  Stream<String> get changes => _changesController.stream;

  void notifyChanged(String profileId) {
    if (!_changesController.isClosed) _changesController.add(profileId);
  }

  void disposeChanges() => _changesController.close();
}
