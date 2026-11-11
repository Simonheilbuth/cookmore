import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/notification_service.dart';

/// The cooking timer. One timer exists for the whole app, so it keeps
/// running while the user moves between screens.
class TimerViewModel extends ChangeNotifier {
  TimerViewModel(this._notifications);

  final NotificationService _notifications;

  static const int minMinutes = 1;
  static const int maxMinutes = 180;

  int _minutes = 10;
  Duration _remaining = const Duration(minutes: 10);
  DateTime? _endsAt;
  Timer? _ticker;
  String _label = '';
  bool _permissionAsked = false;
  bool _notificationsAllowed = false;
  bool _justFinished = false;

  int get minutes => _minutes;
  Duration get remaining => _remaining;
  bool get isRunning => _endsAt != null;
  String get label => _label;
  bool get justFinished => _justFinished;

  /// True when the user said no to notifications. The timer then only
  /// alerts inside the app.
  bool get notificationsBlocked =>
      _permissionAsked && !_notificationsAllowed;

  void setMinutes(int value) {
    if (isRunning) return;
    _minutes = value.clamp(minMinutes, maxMinutes);
    _remaining = Duration(minutes: _minutes);
    _justFinished = false;
    notifyListeners();
  }

  Future<void> start(String label) async {
    if (isRunning || _remaining <= Duration.zero) return;
    _label = label;
    _justFinished = false;

    // Ask for notification permission the first time a timer is started,
    // not when the app opens (only ask when the feature is actually used).
    if (!_permissionAsked) {
      _notificationsAllowed = await _notifications.requestPermission();
      _permissionAsked = true;
    }

    _endsAt = DateTime.now().add(_remaining);
    if (_notificationsAllowed) {
      await _notifications.scheduleTimerFinished(_remaining, label);
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  Future<void> pause() async {
    if (!isRunning) return;
    _tick(notify: false);
    _stopTicker();
    await _notifications.cancelTimer();
    notifyListeners();
  }

  Future<void> reset() async {
    _stopTicker();
    await _notifications.cancelTimer();
    _remaining = Duration(minutes: _minutes);
    _justFinished = false;
    notifyListeners();
  }

  void dismissFinished() {
    _justFinished = false;
    _remaining = Duration(minutes: _minutes);
    notifyListeners();
  }

  /// Remaining time is calculated from the end time (not by counting
  /// ticks), so it stays correct if the app was paused in the background.
  void _tick({bool notify = true}) {
    final endsAt = _endsAt;
    if (endsAt == null) return;
    final left = endsAt.difference(DateTime.now());
    if (left <= Duration.zero) {
      _finish();
      return;
    }
    _remaining = left;
    if (notify) notifyListeners();
  }

  Future<void> _finish() async {
    _stopTicker();
    _remaining = Duration.zero;
    _justFinished = true;
    notifyListeners();
    // Replace the scheduled notification with an immediate one, so it is
    // shown exactly on time and never twice.
    await _notifications.cancelTimer();
    if (_notificationsAllowed) {
      await _notifications.showTimerFinished(_label);
    }
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
