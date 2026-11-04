import 'package:flutter/foundation.dart';

/// A notification to show at a set time, see [ReminderService].
@immutable
final class Reminder {
  /// Creates a reminder.
  const Reminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  /// Notification id; a later reminder with the same id replaces it.
  final int id;

  /// When to show it.
  final DateTime at;

  /// Title of the notification.
  final String title;

  /// Text of the notification.
  final String body;

  /// What the app opens when it is tapped, e.g. `memories` or `ritual:3`.
  final String payload;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, at, title, body, payload);

  @override
  String toString() => 'Reminder($id, $at, $payload)';
}

/// Notifications at set times, without background work (ADR 0027).
///
/// The platform only shows the notifications handed over and sets them
/// again after a reboot; it never reads photos or the database. The app
/// builds the slideshow when a notification is tapped.
abstract interface class ReminderService {
  /// Replaces every pending notification with [reminders].
  Future<void> schedule(List<Reminder> reminders);

  /// Whether notifications are allowed for the app (Android 13+ asks).
  Future<bool> canNotify();

  /// Asks to allow notifications when needed; returns whether they are.
  Future<bool> requestPermission();

  /// Payload of the notification that opened the app, once; `null` when
  /// the app was opened otherwise.
  Future<String?> takeLaunchPayload();

  /// Payloads of notifications tapped while the app runs.
  Stream<String> get taps;
}
