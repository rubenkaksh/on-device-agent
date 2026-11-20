import 'package:flutter/foundation.dart';
import 'package:flutter_gemma_poc/agent/agent_model.dart';
import 'package:flutter_gemma_poc/agent/agent_tool.dart';

/// Result of one agent turn, rendered by the UI.
class AgentTurn {
  const AgentTurn({
    required this.utterance,
    required this.reply,
    this.toolName,
    this.toolArgs = const {},
    this.isSuccess = true,
    this.data = const {},
  });

  final String utterance;
  final String reply;
  final String? toolName;
  final Map<String, dynamic> toolArgs;
  final bool isSuccess;
  final Map<String, dynamic> data;
}

/// Orchestrates utterance → model decision → tool execution.
///
/// Knows nothing about speech, models or storage specifics — each is injected,
/// so any of them can be swapped independently.
class Agent {
  Agent({required this.model, required this.tools, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AgentModel model;
  final ToolRegistry tools;
  final DateTime Function() _clock;

  Future<void> prepare({void Function(int progress)? onProgress}) async {
    await model.initialize();
    if (!await model.isInstalled()) {
      await model.install(onProgress: onProgress);
    }
    await model.load(tools.all);
  }

  Future<AgentTurn> handle(String utterance) async {
    final input = utterance.trim();
    if (input.isEmpty) {
      return const AgentTurn(
        utterance: '',
        reply: "I didn't catch that.",
        isSuccess: false,
      );
    }

    final AgentDecision decision;
    try {
      decision = await model.decide(input, now: _clock());
    } catch (e) {
      debugPrint('Agent: model failed: $e');
      return AgentTurn(
        utterance: input,
        reply: 'The model failed to respond: $e',
        isSuccess: false,
      );
    }
    debugPrint('Agent: $decision');

    switch (decision) {
      case TextDecision(:final text):
        return AgentTurn(
          utterance: input,
          reply: text.isEmpty ? "Sorry, I can't do that yet." : text,
        );
      case ToolCallDecision(:final toolName, :final args):
        final tool = tools[toolName];
        if (tool == null) {
          return AgentTurn(
            utterance: input,
            reply: 'Unknown action "$toolName".',
            toolName: toolName,
            toolArgs: args,
            isSuccess: false,
          );
        }
        try {
          final result = await tool.execute(args);
          return AgentTurn(
            utterance: input,
            reply: result.message,
            toolName: toolName,
            toolArgs: args,
            isSuccess: result.isSuccess,
            data: result.data,
          );
        } catch (e) {
          return AgentTurn(
            utterance: input,
            reply: 'Failed to run $toolName: $e',
            toolName: toolName,
            toolArgs: args,
            isSuccess: false,
          );
        }
    }
  }

  Future<void> dispose() => model.dispose();
}
