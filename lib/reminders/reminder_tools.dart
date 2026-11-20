import 'package:flutter_gemma_poc/agent/agent_tool.dart';
import 'package:flutter_gemma_poc/reminders/natural_date_parser.dart';
import 'package:flutter_gemma_poc/reminders/reminder.dart';

/// All reminder skills, ready to register with the agent.
List<AgentTool> reminderTools(
  ReminderStore store, {
  NaturalDateParser parser = const NaturalDateParser(),
  DateTime Function()? clock,
}) {
  final now = clock ?? DateTime.now;
  return [
    CreateReminderTool(store, parser: parser, clock: now),
    ListRemindersTool(store, clock: now),
    CompleteReminderTool(store),
  ];
}

String formatDue(DateTime due, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  final diff = day.difference(today).inDays;
  final hour = due.hour % 12 == 0 ? 12 : due.hour % 12;
  final minute = due.minute.toString().padLeft(2, '0');
  final time = '$hour:$minute ${due.hour < 12 ? 'AM' : 'PM'}';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final dayLabel = switch (diff) {
    0 => 'today',
    1 => 'tomorrow',
    _ => '${months[due.month - 1]} ${due.day}',
  };
  return '$dayLabel at $time';
}

class CreateReminderTool extends AgentTool {
  CreateReminderTool(
    this.store, {
    this.parser = const NaturalDateParser(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ReminderStore store;
  final NaturalDateParser parser;
  final DateTime Function() _clock;

  @override
  String get name => 'create_reminder';

  @override
  String get description =>
      'Creates a reminder for the user, optionally at a date and time.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'title': {
        'type': 'string',
        'description': 'What to be reminded about, e.g. "call mom".',
      },
      'due': {
        'type': 'string',
        'description':
            'When, in the user\'s own words, e.g. "tomorrow at 5pm" or '
            '"in 20 minutes". Empty if not given.',
      },
    },
    'required': ['title'],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final now = _clock();
    var title = args['title']?.toString().trim() ?? '';
    final dueText = args['due']?.toString().trim() ?? '';

    DateTime? due = parser.parse(dueText, now: now)?.when;
    // Small models sometimes leave the time inside the title.
    if (due == null) {
      final fromTitle = parser.parse(title, now: now);
      if (fromTitle != null && fromTitle.remainder.isNotEmpty) {
        due = fromTitle.when;
        title = fromTitle.remainder;
      }
    }
    title = title.replaceFirst(
      RegExp(r'^(?:to|that)\s+', caseSensitive: false),
      '',
    );
    if (title.isEmpty) {
      return const ToolResult.failure('What should the reminder say?');
    }

    if (!await store.requestAccess()) {
      return const ToolResult.failure(
        'I need Reminders access. Enable it in Settings.',
      );
    }
    final reminder = await store.create(title: title, due: due);
    final when = reminder.due;
    final message = when == null
        ? 'Reminder added: "${reminder.title}".'
        : 'Reminder set: "${reminder.title}" ${formatDue(when, now: now)}.';
    final unparsed = dueText.isNotEmpty && due == null
        ? ' (I couldn\'t understand "$dueText", so it has no time.)'
        : '';
    return ToolResult.success(
      '$message$unparsed',
      data: {'reminder': reminder.toMap()},
    );
  }
}

class ListRemindersTool extends AgentTool {
  ListRemindersTool(this.store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ReminderStore store;
  final DateTime Function() _clock;

  @override
  String get name => 'list_reminders';

  @override
  String get description => 'Lists the user\'s upcoming, incomplete reminders.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    if (!await store.requestAccess()) {
      return const ToolResult.failure(
        'I need Reminders access. Enable it in Settings.',
      );
    }
    final open = await store.listOpen();
    if (open.isEmpty) {
      return const ToolResult.success('You have no open reminders.');
    }
    final now = _clock();
    final lines = [
      for (final r in open.take(10))
        switch (r.due) {
          final DateTime due => '• ${r.title} — ${formatDue(due, now: now)}',
          null => '• ${r.title}',
        },
    ];
    return ToolResult.success(
      'You have ${open.length} open reminder${open.length == 1 ? '' : 's'}:\n'
      '${lines.join('\n')}',
      data: {
        'reminders': [for (final r in open) r.toMap()],
      },
    );
  }
}

class CompleteReminderTool extends AgentTool {
  CompleteReminderTool(this.store);

  final ReminderStore store;

  @override
  String get name => 'complete_reminder';

  @override
  String get description =>
      'Marks an existing reminder as done, found by its title.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'title': {
        'type': 'string',
        'description': 'Title (or part of it) of the reminder to complete.',
      },
    },
    'required': ['title'],
  };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final query = args['title']?.toString().trim().toLowerCase() ?? '';
    if (query.isEmpty) {
      return const ToolResult.failure('Which reminder should I complete?');
    }
    if (!await store.requestAccess()) {
      return const ToolResult.failure(
        'I need Reminders access. Enable it in Settings.',
      );
    }
    final open = await store.listOpen();
    final matches = open
        .where((r) => r.title.toLowerCase().contains(query))
        .toList();
    if (matches.isEmpty) {
      return ToolResult.failure('No open reminder matches "$query".');
    }
    if (matches.length > 1) {
      final titles = matches.map((r) => '"${r.title}"').join(', ');
      return ToolResult.failure('Which one? $titles');
    }
    final match = matches.single;
    await store.complete(match.id);
    return ToolResult.success(
      'Marked "${match.title}" as done.',
      data: {'reminder': match.copyWith(isCompleted: true).toMap()},
    );
  }
}
