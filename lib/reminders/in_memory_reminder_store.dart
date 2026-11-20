import 'package:flutter_gemma_poc/reminders/reminder.dart';

/// Non-persistent [ReminderStore] for tests, desktop runs and platforms
/// without a native store yet.
class InMemoryReminderStore implements ReminderStore {
  final _reminders = <Reminder>[];
  int _nextId = 1;

  @override
  String get displayName => 'In-memory (not saved)';

  @override
  Future<bool> requestAccess() async => true;

  @override
  Future<Reminder> create({required String title, DateTime? due}) async {
    final reminder = Reminder(id: '${_nextId++}', title: title, due: due);
    _reminders.add(reminder);
    return reminder;
  }

  @override
  Future<List<Reminder>> listOpen() async {
    final open = _reminders.where((r) => !r.isCompleted).toList()
      ..sort((a, b) {
        final aDue = a.due;
        final bDue = b.due;
        if (aDue == null) return bDue == null ? 0 : 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      });
    return open;
  }

  @override
  Future<void> complete(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) throw StateError('No reminder with id $id.');
    _reminders[index] = _reminders[index].copyWith(isCompleted: true);
  }
}
