import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications for the cooking timer (native functionality).
///
/// On Android and iOS a notification is scheduled when the timer starts, so
/// the user is alerted even if the app is closed. On Windows the app shows
/// the notification itself when the countdown reaches zero.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _timerNotificationId = 1;

  bool _initialized = false;

  /// False if notifications are not supported on this device or could not
  /// be initialised. The timer still works inside the app in that case.
  bool get isSupported => _initialized;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  static final NotificationDetails _timerDetails = const NotificationDetails(
    android: AndroidNotificationDetails(
      'cooking_timer',
      'Cooking timer',
      channelDescription: 'Alerts when a cooking timer has finished.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(presentSound: true),
    windows: const WindowsNotificationDetails(),
  );

  Future<void> init() async {
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
      return;
    }
    try {
      tz_data.initializeTimeZones();

      final settings = const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested later, when the user starts a timer.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: const WindowsInitializationSettings(
          appName: 'CookMore',
          appUserModelId: 'Dk.CookMore.App',
          guid: '5b6f2c1e-8d3a-4f7b-9c2e-1a4d6e8f0b3c',
        ),
      );
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (error) {
      debugPrint('NotificationService: init failed: $error');
      _initialized = false;
    }
  }

  /// Asks for permission to show notifications. Returns true if allowed.
  ///
  /// Android 13+ and iOS need a runtime permission. Windows does not.
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(alert: true, sound: true) ?? false;
      }
      return true;
    } catch (error) {
      debugPrint('NotificationService: permission request failed: $error');
      return false;
    }
  }

  /// Schedules the "timer finished" notification on Android/iOS.
  ///
  /// An inexact schedule is used so the app does not need the special
  /// "exact alarm" permission. It may arrive a little late if the phone is
  /// in deep sleep, but the in-app countdown is always exact.
  Future<void> scheduleTimerFinished(Duration after, String label) async {
    if (!_initialized || !_isMobile) return;
    try {
      await _plugin.zonedSchedule(
        _timerNotificationId,
        'Timer finished',
        _bodyFor(label),
        tz.TZDateTime.now(tz.UTC).add(after),
        _timerDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('NotificationService: scheduling failed: $error');
    }
  }

  /// Shows the "timer finished" notification right away.
  Future<void> showTimerFinished(String label) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        _timerNotificationId,
        'Timer finished',
        _bodyFor(label),
        _timerDetails,
      );
    } catch (error) {
      debugPrint('NotificationService: show failed: $error');
    }
  }

  Future<void> cancelTimer() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_timerNotificationId);
    } catch (error) {
      debugPrint('NotificationService: cancel failed: $error');
    }
  }

  String _bodyFor(String label) => label.isEmpty
      ? 'Your cooking timer is done.'
      : '$label is ready to check!';
}
