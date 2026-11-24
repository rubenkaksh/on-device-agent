import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Appends [line] to `Documents/agent_log.txt` in the app container so a
/// connected Mac can pull it with `devicectl device copy from`. Best effort:
/// logging must never break the agent.
Future<void> appendAgentLog(String line) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    await File(
      '${dir.path}/agent_log.txt',
    ).writeAsString('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // Ignore: diagnostics only.
  }
}
