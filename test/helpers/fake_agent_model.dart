import 'package:flutter_gemma_poc/agent/agent_model.dart';
import 'package:flutter_gemma_poc/agent/agent_tool.dart';

/// Scripted [AgentModel]: returns [decisions] in order, or a fallback
/// computed by [decider]. Never touches platform channels.
class FakeAgentModel implements AgentModel {
  FakeAgentModel({List<AgentDecision>? decisions, this.decider})
    : _decisions = [...?decisions];

  final List<AgentDecision> _decisions;
  final AgentDecision Function(String utterance)? decider;

  final utterances = <String>[];
  List<AgentTool> loadedTools = const [];
  bool installed = true;
  int installCalls = 0;

  @override
  String get displayName => 'Fake model';

  @override
  bool isReady = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<void> install({void Function(int progress)? onProgress}) async {
    installCalls++;
    onProgress?.call(100);
    installed = true;
  }

  @override
  Future<void> load(List<AgentTool> tools) async {
    loadedTools = tools;
    isReady = true;
  }

  @override
  Future<AgentDecision> decide(String utterance, {required DateTime now}) async {
    utterances.add(utterance);
    if (_decisions.isNotEmpty) return _decisions.removeAt(0);
    final decide = decider;
    if (decide != null) return decide(utterance);
    return const TextDecision('');
  }

  @override
  Future<void> dispose() async {}
}
