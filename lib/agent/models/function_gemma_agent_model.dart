import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:flutter_gemma_poc/agent/agent_model.dart';
import 'package:flutter_gemma_poc/agent/agent_tool.dart';
import 'package:flutter_gemma_poc/config/env_config.dart';

/// [AgentModel] backed by FunctionGemma 270M via flutter_gemma.
///
/// FunctionGemma is single-turn: flutter_gemma clears its history after every
/// call, so each utterance is decided independently. Tool arguments are kept
/// as the user's own words (e.g. `due: "tomorrow at 5pm"`) and resolved in
/// Dart — a 270M model shouldn't be trusted with date arithmetic.
class FunctionGemmaAgentModel implements AgentModel {
  FunctionGemmaAgentModel({String? modelUrl})
    : modelUrl =
          modelUrl ?? envValue('AGENT_MODEL_URL') ?? defaultFunctionGemmaUrl;

  static const defaultFunctionGemmaUrl =
      'https://huggingface.co/sasha-denisov/function-gemma-270M-it/resolve/main/functiongemma-270M-it.litertlm';

  final String modelUrl;

  static const _fileType = ModelFileType.litertlm;

  bool _initialized = false;
  InferenceModel? _model;
  InferenceChat? _chat;
  Future<void>? _inFlight;

  String get _modelId => Uri.parse(modelUrl).pathSegments.last;

  @override
  String get displayName => 'FunctionGemma 270M';

  @override
  bool get isReady => _chat != null;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await FlutterGemma.initialize(
      huggingFaceToken: envValue('HF_TOKEN') ?? '',
      inferenceEngines: [MediaPipeEngine(), LiteRtLmEngine()],
    );
    _initialized = true;
  }

  @override
  Future<bool> isInstalled() async {
    if (!_initialized) return false;
    return FlutterGemma.isModelInstalled(_modelId);
  }

  @override
  Future<void> install({void Function(int progress)? onProgress}) =>
      _activate(onProgress: onProgress);

  /// Installs (downloads only if missing) and marks this model active. Must
  /// run before [load] because the chat screen may have activated Gemma 3n.
  Future<void> _activate({void Function(int progress)? onProgress}) async {
    if (!_initialized) throw StateError('Call initialize() first.');
    await FlutterGemma.installModel(
      modelType: ModelType.functionGemma,
      fileType: _fileType,
    ).fromNetwork(modelUrl).withProgress(onProgress ?? (_) {}).install();
  }

  @override
  Future<void> load(List<AgentTool> tools) async {
    await _activate();
    await _closeModel();
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.cpu,
    );
    _model = model;
    _chat = await model.createChat(
      temperature: 0.0,
      topK: 1,
      randomSeed: 1,
      modelType: ModelType.functionGemma,
      supportsFunctionCalls: true,
      tools: [
        for (final tool in tools)
          Tool(
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters,
          ),
      ],
    );
  }

  @override
  Future<AgentDecision> decide(
    String utterance, {
    required DateTime now,
  }) async {
    final chat = _chat;
    if (chat == null) throw StateError('Call load() first.');

    // The native session rejects overlapping queries; serialize them.
    final previous = _inFlight;
    if (previous != null) await previous;

    final run = () async {
      // Every utterance is decided alone; don't trust the plugin to have
      // dropped the previous turn's state.
      await chat.clearHistory();
      await chat.addQuery(Message.text(text: utterance, isUser: true));
      return chat.generateChatResponse();
    }();
    _inFlight = run.then<void>((_) {}, onError: (_) {});

    final response = await run;
    return switch (response) {
      FunctionCallResponse(:final name, :final args) => ToolCallDecision(
        name,
        args,
      ),
      ParallelFunctionCallResponse(:final calls) when calls.isNotEmpty =>
        ToolCallDecision(calls.first.name, calls.first.args),
      TextResponse(:final token) => TextDecision(token.trim()),
      _ => const TextDecision(''),
    };
  }

  Future<void> _closeModel() async {
    final model = _model;
    _model = null;
    _chat = null;
    if (model != null) await model.close();
  }

  @override
  Future<void> dispose() => _closeModel();
}
