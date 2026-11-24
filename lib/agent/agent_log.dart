import 'dart:io';

/// Appends [line] to `Documents/agent_log.txt` in the app container so a
/// connected Mac can pull it with `devicectl device copy from`. Best effort:
/// logging must never break the agent.
void appendAgentLog(String line) {
  try {
    final home = Platform.environment['HOME'];
    if (home == null) return;
    final dir = Directory('$home/Documents');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File(
      '${dir.path}/agent_log.txt',
    ).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // Ignore: diagnostics only.
  }
}
