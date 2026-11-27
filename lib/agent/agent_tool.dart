/// A capability the agent can invoke (e.g. "create a reminder").
///
/// Tools are model-agnostic: an [AgentModel] only sees [name], [description]
/// and [parameters] (a JSON-schema object). Add a new skill by implementing
/// this class and registering it in the [ToolRegistry] — no model or UI
/// changes needed.
abstract class AgentTool {
  const AgentTool();

  /// Key under which the agent passes the user's own words to [execute].
  /// Small models garble or invent arguments; tools may use the raw
  /// utterance as the source of truth for things like dates.
  static const utteranceArg = '_utterance';

  /// Snake-case function name the model calls, e.g. `create_reminder`.
  String get name;

  /// One-line description the model uses to pick this tool.
  String get description;

  /// JSON-schema `object` describing the arguments.
  Map<String, dynamic> get parameters;

  /// Run the tool with model-provided [args].
  Future<ToolResult> execute(Map<String, dynamic> args);
}

/// Outcome of running an [AgentTool].
class ToolResult {
  const ToolResult.success(this.message, {this.data = const {}})
    : isSuccess = true;

  const ToolResult.failure(this.message, {this.data = const {}})
    : isSuccess = false;

  final bool isSuccess;

  /// Human-readable summary shown (and optionally spoken) to the user.
  final String message;

  /// Structured payload, e.g. the created reminder, for UI cards.
  final Map<String, dynamic> data;
}

/// Name → tool lookup shared by the agent and its model.
class ToolRegistry {
  ToolRegistry(Iterable<AgentTool> tools)
    : _tools = {for (final tool in tools) tool.name: tool};

  final Map<String, AgentTool> _tools;

  List<AgentTool> get all => List.unmodifiable(_tools.values);

  AgentTool? operator [](String name) => _tools[name];
}
