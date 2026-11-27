import 'package:flutter/services.dart';
import 'package:flutter_gemma_poc/reminders/reminder.dart';

/// [ReminderStore] backed by iOS EventKit (the system Reminders app).
///
/// Native side: `ios/Runner/RemindersChannel.swift`. Reminders created here
/// show up in Apple Reminders and fire native alerts at their due time.
class EventKitReminderStore implements ReminderStore {
  EventKitReminderStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'on_device_agent/reminders';

  final MethodChannel _channel;

  @override
  String get displayName => 'Apple Reminders';

  @override
  Future<bool> requestAccess() async =>
      await _channel.invokeMethod<bool>('requestAccess') ?? false;

  @override
  Future<Reminder> create({required String title, DateTime? due}) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'create',
      {'title': title, 'dueMillis': due?.millisecondsSinceEpoch},
    );
    if (result == null) {
      throw PlatformException(code: 'EMPTY', message: 'No reminder returned.');
    }
    return Reminder.fromMap(result);
  }

  @override
  Future<List<Reminder>> listOpen() async {
    final result =
        await _channel.invokeListMethod<Map<Object?, Object?>>('listOpen') ??
        const [];
    return [for (final map in result) Reminder.fromMap(map)];
  }

  @override
  Future<void> complete(String id) =>
      _channel.invokeMethod<void>('complete', {'id': id});
}
