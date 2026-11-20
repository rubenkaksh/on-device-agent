import 'package:flutter_gemma_poc/agent/agent_tool.dart';

/// Plug-and-play contract for the model that turns an utterance into an
/// action. Implement this to swap FunctionGemma for Gemma 4, a Qwen GGUF via
/// NobodyWho, Cactus, a rules engine, etc. Select the implementation in
/// `agent_model_factory.dart` (or via `AGENT_MODEL` in `.env`).
abstract interface class AgentModel {
  /// Short name shown in the UI.
  String get displayName;

  bool get isReady;

  /// One-time engine setup (plugin init, native libs).
  Future<void> initialize();

  /// Whether the model weights are already on the device.
  Future<bool> isInstalled();

  /// Download/install the weights. [onProgress] receives 0-100.
  Future<void> install({void Function(int progress)? onProgress});

  /// Load the weights and prepare a session that knows about [tools].
  Future<void> load(List<AgentTool> tools);

  /// Decide what to do with [utterance]: call a tool or reply with text.
  ///
  /// [now] is passed so implementations can ground relative dates.
  Future<AgentDecision> decide(String utterance, {required DateTime now});

  Future<void> dispose();
}

/// What the model decided to do for one utterance.
sealed class AgentDecision {
  const AgentDecision();
}

/// The model wants [toolName] run with [args].
class ToolCallDecision extends AgentDecision {
  const ToolCallDecision(this.toolName, this.args);

  final String toolName;
  final Map<String, dynamic> args;

  @override
  String toString() => 'ToolCallDecision($toolName, $args)';
}

/// The model answered in plain text (no tool matched).
class TextDecision extends AgentDecision {
  const TextDecision(this.text);

  final String text;

  @override
  String toString() => 'TextDecision($text)';
}
