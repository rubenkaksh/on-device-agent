/// A reminder, independent of where it is stored.
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    this.due,
    this.isCompleted = false,
  });

  factory Reminder.fromMap(Map<Object?, Object?> map) {
    final dueMillis = map['dueMillis'];
    return Reminder(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      due: dueMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(dueMillis)
          : null,
      isCompleted: map['isCompleted'] == true,
    );
  }

  final String id;
  final String title;
  final DateTime? due;
  final bool isCompleted;

  Reminder copyWith({bool? isCompleted}) => Reminder(
    id: id,
    title: title,
    due: due,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'dueMillis': due?.millisecondsSinceEpoch,
    'isCompleted': isCompleted,
  };
}

/// Plug-and-play storage for reminders.
///
/// [EventKitReminderStore] writes to Apple's Reminders app. Implement this
/// for Android, a local DB, Google Tasks, etc. and swap it in
/// `reminder_store_factory.dart`.
abstract interface class ReminderStore {
  String get displayName;

  /// Ask for access. Returns `false` if the user denied it.
  Future<bool> requestAccess();

  Future<Reminder> create({required String title, DateTime? due});

  /// Incomplete reminders, soonest due first.
  Future<List<Reminder>> listOpen();

  Future<void> complete(String id);
}
