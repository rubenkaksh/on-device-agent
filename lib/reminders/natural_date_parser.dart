/// Result of [NaturalDateParser.parse].
class ParsedDate {
  const ParsedDate(this.when, this.remainder);

  final DateTime when;

  /// Input with the date/time words removed (e.g. "call mom").
  final String remainder;
}

/// Resolves spoken date/time phrases ("tomorrow at 5pm", "in 20 minutes",
/// "next friday morning") against a reference time.
///
/// Deliberately small and deterministic so the model only has to copy the
/// user's words into the `due` argument. Swap for a richer resolver by
/// implementing the same `parse` signature.
class NaturalDateParser {
  const NaturalDateParser({this.defaultHour = 9});

  /// Hour used when a day is given without a time.
  final int defaultHour;

  static const _weekdays = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  static const _numberWords = {
    'a': 1,
    'an': 1,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'fifteen': 15,
    'twenty': 20,
    'thirty': 30,
    'forty five': 45,
  };

  static const _partsOfDay = {
    'morning': 9,
    'noon': 12,
    'afternoon': 15,
    'evening': 18,
    'tonight': 20,
    'night': 20,
    'midnight': 0,
  };

  /// Returns `null` when [input] contains no recognisable date or time.
  ParsedDate? parse(String input, {required DateTime now}) {
    var text = ' ${input.toLowerCase().replaceAll(RegExp(r'[,.!?]'), ' ')} ';
    text = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('half an hour', '30 minutes')
        .replaceAll('half hour', '30 minutes');

    // 1. ISO timestamps the model may emit directly.
    final iso = RegExp(
      r'\b(\d{4}-\d{2}-\d{2})(?:[t ](\d{2}:\d{2}))?\b',
    ).firstMatch(text);
    if (iso != null) {
      final date = iso.group(1) ?? '';
      final time = iso.group(2);
      final parsed = DateTime.tryParse(
        time == null ? '${date}T${_two(defaultHour)}:00' : '${date}T$time',
      );
      if (parsed != null) {
        return ParsedDate(
          parsed,
          _clean(text.replaceFirst(iso.group(0) ?? '', ' ')),
        );
      }
    }

    // 2. Relative offsets: "in 20 minutes", "in an hour", "in half an hour".
    final numberAlt = [
      r'\d+',
      ..._numberWords.keys.toList()..sort((a, b) => b.length - a.length),
    ].join('|');
    final relative = RegExp(
      '\\b(?:in|after) ($numberAlt) (minute|min|hour|hr|day|week)s?\\b',
    ).firstMatch(text);
    if (relative != null) {
      final raw = relative.group(1) ?? '';
      final amount = int.tryParse(raw) ?? _numberWords[raw] ?? 0;
      final unit = relative.group(2) ?? '';
      final offset = switch (unit) {
        'minute' || 'min' => Duration(minutes: amount),
        'hour' || 'hr' => Duration(hours: amount),
        'day' => Duration(days: amount),
        _ => Duration(days: 7 * amount),
      };
      return ParsedDate(
        now.add(offset),
        _clean(text.replaceFirst(relative.group(0) ?? '', ' ')),
      );
    }

    // 3. Absolute day + optional time.
    DateTime? day;
    final consumed = <String>[];

    final dayAfter = RegExp(r'\bday after tomorrow\b').firstMatch(text);
    final tomorrow = RegExp(r'\b(?:tomorrow|tmrw|tmr)\b').firstMatch(text);
    final today = RegExp(r'\btoday\b').firstMatch(text);
    final weekday = RegExp(
      '\\b(?:(next|this|on) )?(${_weekdays.keys.join('|')})\\b',
    ).firstMatch(text);

    if (dayAfter != null) {
      day = _dateOnly(now).add(const Duration(days: 2));
      consumed.add(dayAfter.group(0) ?? '');
    } else if (tomorrow != null) {
      day = _dateOnly(now).add(const Duration(days: 1));
      consumed.add(tomorrow.group(0) ?? '');
    } else if (weekday != null) {
      final target = _weekdays[weekday.group(2)] ?? now.weekday;
      var delta = (target - now.weekday) % 7;
      if (delta == 0) delta = 7;
      day = _dateOnly(now).add(Duration(days: delta));
      consumed.add(weekday.group(0) ?? '');
    } else if (today != null) {
      day = _dateOnly(now);
      consumed.add(today.group(0) ?? '');
    }

    // Clock time: "at 5", "5pm", "5:30 pm", "17:30", "5 o'clock".
    int? hour;
    int minute = 0;
    final clock = RegExp(
      r"\b(?:at )?(\d{1,2})(?::(\d{2}))? ?(am|pm|a m|p m|o'clock|oclock)?\b",
    ).allMatches(text).where((m) {
      final hasMarker = m.group(2) != null || m.group(3) != null;
      final hasAt = (m.group(0) ?? '').startsWith('at ');
      return hasMarker || hasAt;
    }).firstOrNull;
    if (clock != null) {
      hour = int.tryParse(clock.group(1) ?? '');
      minute = int.tryParse(clock.group(2) ?? '') ?? 0;
      final marker = (clock.group(3) ?? '').replaceAll(' ', '');
      final h = hour;
      if (h != null) {
        if (marker == 'pm' && h < 12) hour = h + 12;
        if (marker == 'am' && h == 12) hour = 0;
        // Bare "at 5" with no am/pm: assume the next occurrence in daytime.
        if (marker.isEmpty || marker.contains('clock')) {
          if (h < 8) hour = h + 12;
        }
      }
      consumed.add(clock.group(0) ?? '');
    }

    // Part of day: "tomorrow morning", "this evening", "tonight".
    final partMatch = RegExp(
      '\\b(?:(?:in )?the |this )?(${_partsOfDay.keys.join('|')})\\b',
    ).firstMatch(text);
    if (partMatch != null) {
      final partHour = _partsOfDay[partMatch.group(1)];
      if (hour == null && partHour != null) hour = partHour;
      final h = hour;
      // "at 7 in the evening" → 19:00.
      if (h != null && h < 12 && (partHour ?? 0) >= 15) hour = h + 12;
      consumed.add(partMatch.group(0) ?? '');
      day ??= _dateOnly(now);
    }

    final resolvedHour = hour;
    if (day == null && resolvedHour == null) return null;
    if (resolvedHour != null && (resolvedHour > 23 || minute > 59)) return null;

    var when = DateTime(
      (day ?? now).year,
      (day ?? now).month,
      (day ?? now).day,
      resolvedHour ?? defaultHour,
      minute,
    );
    // Time only and already past → tomorrow.
    if (day == null && !when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }

    var remainder = text;
    for (final part in consumed) {
      if (part.isNotEmpty) remainder = remainder.replaceFirst(part, ' ');
    }
    return ParsedDate(when, _clean(remainder));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _clean(String s) => s
      .replaceAll(RegExp(r'\b(?:on|at|by)\s*$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
