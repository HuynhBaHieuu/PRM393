import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:all_fits/core/constants/app_config.dart';

/// Fits' "Daily reminders": one notification a day to log the outfit of
/// the day. Abstract so tests and unsupported platforms can skip it.
abstract interface class ReminderService {
  /// Asks for permission if needed and starts the daily reminder. Resolves
  /// to false when the user doesn't allow notifications.
  Future<bool> enableDaily();

  Future<void> disableDaily();
}

/// Does nothing; used in tests and where notifications aren't supported.
class NoReminderService implements ReminderService {
  const NoReminderService();

  @override
  Future<bool> enableDaily() async => true;

  @override
  Future<void> disableDaily() async {}
}

/// Android reminders through flutter_local_notifications. The repeat is
/// inexact, so no exact-alarm permission is needed.
class LocalReminderService implements ReminderService {
  LocalReminderService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int _dailyId = 1;
  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'daily_reminder',
    'Daily reminder',
    channelDescription: 'A reminder to log your outfit of the day',
  );

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> enableDaily() async {
    try {
      await _init();
      final allowed = await _androidPlugin?.requestNotificationsPermission();
      if (allowed == false) return false;
      await _plugin.periodicallyShow(
        id: _dailyId,
        repeatInterval: RepeatInterval.daily,
        notificationDetails: const NotificationDetails(android: _android),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'What are you wearing today?',
        body: 'Log your outfit of the day in ${AppConfig.appName}.',
      );
      return true;
    } catch (error) {
      developer.log('Reminder not scheduled', name: 'reminder', error: error);
      return false;
    }
  }

  @override
  Future<void> disableDaily() async {
    try {
      await _init();
      await _plugin.cancel(id: _dailyId);
    } catch (error) {
      developer.log('Reminder not cancelled', name: 'reminder', error: error);
    }
  }
}
