import 'dart:math';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform, TimeOfDay;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Persisted daily local notification to nudge reflection.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _prefsEnabled = 'daily_reminder_enabled';
  static const _prefsHour = 'daily_reminder_hour';
  static const _prefsMinute = 'daily_reminder_minute';

  static const defaultHour = 21;
  static const defaultMinute = 0;

  static const _channelId = 'mindtape_daily_reminder';
  /// First notification id; we use [_idBase]…[_idBase + _windowDays - 1] for a rolling window.
  static const _idBase = 9001;
  static const _windowDays = 45;

  static const List<String> _bodies = [
    'Hey, how was your day? 🎤',
    'Time to capture your thoughts',
    "Don't lose today's story",
    'A minute for you — how are you feeling?',
    'Your day deserves a line in MindTape.',
    'Pause and put today into words.',
    'Reflection time — what stood out today?',
    'Close the loop on today with a quick note.',
  ];

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get _canSchedule {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static String _bodyForCalendarDay(tz.TZDateTime when) {
    final seed = DateTime(when.year, when.month, when.day).millisecondsSinceEpoch;
    return _bodies[Random(seed).nextInt(_bodies.length)];
  }

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    // Must match a drawable under android/app/src/main/res/drawable/ (this project uses @drawable/ic_launcher).
    const androidInit = AndroidInitializationSettings('@drawable/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings: settings);

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Daily reminder',
        description: 'Reminder to reflect with MindTape',
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<DailyReminderSettings> loadSettings() async {
    final p = await SharedPreferences.getInstance();
    return DailyReminderSettings(
      enabled: p.getBool(_prefsEnabled) ?? false,
      hour: p.getInt(_prefsHour) ?? defaultHour,
      minute: p.getInt(_prefsMinute) ?? defaultMinute,
    );
  }

  /// Asks for notification visibility + (Android 12+) exact alarm access when relevant.
  Future<bool> ensureNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(alert: true, sound: true, badge: false);
      if (granted == false) return false;
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notif = await android?.requestNotificationsPermission();
      if (notif != null && !notif) return false;
      await android?.requestExactAlarmsPermission();
      return true;
    }

    return true;
  }

  Future<void> _cancelReminderWindow() async {
    for (var i = 0; i < _windowDays; i++) {
      await _plugin.cancel(id: _idBase + i);
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsEnabled, enabled);
    if (!enabled) {
      await _cancelReminderWindow();
      return;
    }
    final hour = p.getInt(_prefsHour) ?? defaultHour;
    final minute = p.getInt(_prefsMinute) ?? defaultMinute;
    await scheduleDaily(hour, minute);
  }

  Future<void> setTime(int hour, int minute) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefsHour, hour);
    await p.setInt(_prefsMinute, minute);
    if (p.getBool(_prefsEnabled) ?? false) {
      await scheduleDaily(hour, minute);
    }
  }

  Future<void> applySavedSchedule() async {
    if (!_canSchedule || !_initialized) return;
    final s = await loadSettings();
    if (s.enabled) await scheduleDaily(s.hour, s.minute);
  }

  /// Schedules [_windowDays] separate one-shot notifications so each day can use a different message
  /// and alarms fire at the chosen clock time (exact on Android when permitted).
  Future<void> scheduleDaily(int hour, int minute) async {
    if (!_canSchedule || !_initialized) return;

    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!first.isAfter(now)) {
      first = first.add(const Duration(days: 1));
    }

    await _cancelReminderWindow();

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid) {
      try {
        await _scheduleWindow(first, AndroidScheduleMode.exactAllowWhileIdle);
        return;
      } on PlatformException catch (_) {
        await _cancelReminderWindow();
      }
    }

    await _scheduleWindow(first, AndroidScheduleMode.inexactAllowWhileIdle);
  }

  Future<void> _scheduleWindow(tz.TZDateTime first, AndroidScheduleMode androidMode) async {
    for (var i = 0; i < _windowDays; i++) {
      final fire = first.add(Duration(days: i));
      await _plugin.zonedSchedule(
        id: _idBase + i,
        title: 'MindTape',
        body: _bodyForCalendarDay(fire),
        scheduledDate: fire,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Daily reminder',
            channelDescription: 'Reminder to reflect with MindTape',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: androidMode,
      );
    }
  }
}

class DailyReminderSettings {
  const DailyReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);
}
