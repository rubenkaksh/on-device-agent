import 'package:flutter/foundation.dart';
import 'package:flutter_gemma_poc/reminders/eventkit_reminder_store.dart';
import 'package:flutter_gemma_poc/reminders/in_memory_reminder_store.dart';
import 'package:flutter_gemma_poc/reminders/reminder.dart';

/// Apple Reminders on iOS; in-memory elsewhere until an Android store exists.
///
/// To plug in a new store: implement [ReminderStore] and return it here.
ReminderStore createReminderStore() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return EventKitReminderStore();
  }
  return InMemoryReminderStore();
}
