import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tells the app whether the device has a network connection.
///
/// Note: having a network does not guarantee that the internet works, so
/// callers still handle failed requests. This is only used to know when it
/// is worth trying to sync again.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Emits true when the device comes online and false when it goes offline.
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged
      .map(_hasConnection)
      .handleError((Object error) {
        debugPrint('ConnectivityService: $error');
      })
      .distinct();

  Future<bool> isOnline() async {
    try {
      return _hasConnection(await _connectivity.checkConnectivity());
    } catch (error) {
      debugPrint('ConnectivityService: $error');
      // If the check fails, assume online and let the request decide.
      return true;
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
