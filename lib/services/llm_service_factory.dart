import 'package:flutter_gemma_poc/config/env_config.dart';
import 'package:flutter_gemma_poc/services/gemma_service.dart';
import 'package:flutter_gemma_poc/services/llm_service.dart';
import 'package:flutter_gemma_poc/services/nobodywho_service.dart';

/// Backend selected by `LLM_BACKEND` in `.env`: `gemma` (default) or
/// `nobodywho`. Unknown values fall back to `gemma`.
enum LlmBackend {
  gemma,
  nobodywho;

  static LlmBackend fromEnv() => switch (envValue('LLM_BACKEND')?.trim()) {
    'nobodywho' => LlmBackend.nobodywho,
    _ => LlmBackend.gemma,
  };
}

LlmService createLlmService([LlmBackend? backend]) =>
    switch (backend ?? LlmBackend.fromEnv()) {
      LlmBackend.gemma => GemmaService(),
      LlmBackend.nobodywho => NobodyWhoService(),
    };
