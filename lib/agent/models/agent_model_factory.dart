import 'package:flutter_gemma_poc/agent/agent_model.dart';
import 'package:flutter_gemma_poc/agent/models/function_gemma_agent_model.dart';
import 'package:flutter_gemma_poc/config/env_config.dart';

/// Agent model selected by `AGENT_MODEL` in `.env`.
///
/// To plug in a new model: implement [AgentModel], add an enum value here and
/// a branch in [createAgentModel]. Nothing else changes.
enum AgentModelKind {
  functionGemma;

  static AgentModelKind fromEnv() => switch (envValue('AGENT_MODEL')?.trim()) {
    _ => AgentModelKind.functionGemma,
  };
}

AgentModel createAgentModel([AgentModelKind? kind]) =>
    switch (kind ?? AgentModelKind.fromEnv()) {
      AgentModelKind.functionGemma => FunctionGemmaAgentModel(),
    };
