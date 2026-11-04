import 'dart:async';

import 'package:clean_gallery/platform/reminder_service.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Android [ReminderService]: `Reminders.kt` keeps the notifications and
/// sets one inexact alarm for the earliest; `ReminderReceiver` shows them
/// and sets the alarm again after a reboot. Taps come back over the
/// `clean_gallery/reminders` channel. See `docs/platform-android.md`.
final class AndroidReminderService implements ReminderService {
  /// Creates the service. The channels can be replaced in tests.
  AndroidReminderService({MethodChannel? channel, MethodChannel? taps})
    : _channel = channel ?? const MethodChannel('clean_gallery/platform'),
      _tapChannel = taps ?? const MethodChannel('clean_gallery/reminders') {
    _tapChannel.setMethodCallHandler((call) async {
      if (call.method == 'reminderTapped' && call.arguments is String) {
        _taps.add(call.arguments as String);
      }
    });
  }

  final MethodChannel _channel;
  final MethodChannel _tapChannel;
  final _taps = StreamController<String>.broadcast();

  @override
  Future<void> schedule(List<Reminder> reminders) =>
      _channel.invokeMethod<void>('scheduleReminders', {
        'reminders': [
          for (final reminder in reminders)
            {
              'id': reminder.id,
              'at': reminder.at.millisecondsSinceEpoch,
              'title': reminder.title,
              'body': reminder.body,
              'payload': reminder.payload,
            },
        ],
      });

  @override
  Future<bool> canNotify() async =>
      await _channel.invokeMethod<bool>('canNotify') ?? false;

  @override
  Future<bool> requestPermission() async {
    if (await canNotify()) return true;
    // POST_NOTIFICATIONS exists from Android 13; below, it is granted.
    final status = await ph.Permission.notification.request();
    return status.isGranted || await canNotify();
  }

  @override
  Future<String?> takeLaunchPayload() =>
      _channel.invokeMethod<String>('takeReminderPayload');

  @override
  Stream<String> get taps => _taps.stream;
}
