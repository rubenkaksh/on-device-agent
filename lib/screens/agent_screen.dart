import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gemma_poc/agent/agent.dart';
import 'package:flutter_gemma_poc/speech/speech_input.dart';

/// M1 assistant: tap the mic, speak ("remind me to call mom tomorrow at
/// 5pm"), and the on-device agent runs the matching tool. Typing works too.
class AgentScreen extends StatefulWidget {
  const AgentScreen({
    super.key,
    required this.agent,
    required this.speech,
    this.onOpenChat,
  });

  final Agent agent;
  final SpeechInput speech;

  /// Opens the original Gemma chat POC, if provided.
  final VoidCallback? onOpenChat;

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

enum _Phase { preparing, ready, listening, thinking, failed }

class _AgentScreenState extends State<AgentScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _turns = <AgentTurn>[];

  _Phase _phase = _Phase.preparing;
  int _progress = 0;
  String _partial = '';
  String? _error;
  bool _speechAvailable = false;
  StreamSubscription<SpeechTranscript>? _speechSub;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    setState(() {
      _phase = _Phase.preparing;
      _error = null;
    });
    try {
      await widget.agent.prepare(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      final speechOk = await widget.speech.initialize();
      if (!mounted) return;
      setState(() {
        _speechAvailable = speechOk;
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = 'Setup failed: $e';
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_phase == _Phase.listening) {
      await widget.speech.stop();
      return;
    }
    if (_phase != _Phase.ready) return;

    setState(() {
      _phase = _Phase.listening;
      _partial = '';
      _error = null;
    });

    var finalText = '';
    _speechSub = widget.speech.listen().listen(
      (t) {
        finalText = t.text;
        if (mounted) setState(() => _partial = t.text);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.ready;
          _error = 'Speech error: $e';
        });
      },
      onDone: () {
        _speechSub = null;
        if (!mounted) return;
        if (_phase != _Phase.listening) return;
        if (finalText.trim().isEmpty) {
          setState(() => _phase = _Phase.ready);
        } else {
          unawaited(_run(finalText));
        }
      },
    );
  }

  Future<void> _submitText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _phase != _Phase.ready) return;
    _textController.clear();
    await _run(text);
  }

  Future<void> _run(String utterance) async {
    setState(() {
      _phase = _Phase.thinking;
      _partial = utterance;
    });
    final turn = await widget.agent.handle(utterance);
    if (!mounted) return;
    setState(() {
      _turns.add(turn);
      _partial = '';
      _phase = _Phase.ready;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_speechSub?.cancel());
    unawaited(widget.speech.cancel());
    unawaited(widget.agent.dispose());
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onOpenChat = widget.onOpenChat;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          if (onOpenChat != null)
            IconButton(
              tooltip: 'Gemma chat',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: onOpenChat,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                widget.agent.model.displayName,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            Expanded(child: _buildBody(context)),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _buildInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case _Phase.preparing:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: _progress > 0 && _progress < 100 ? _progress / 100 : null,
              ),
              const SizedBox(height: 12),
              Text(
                _progress > 0 && _progress < 100
                    ? 'Downloading model… $_progress%'
                    : 'Loading model…',
              ),
            ],
          ),
        );
      case _Phase.failed:
        return Center(
          child: FilledButton(onPressed: _prepare, child: const Text('Retry')),
        );
      case _Phase.ready || _Phase.listening || _Phase.thinking:
        if (_turns.isEmpty && _partial.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Try: "Remind me to call mom tomorrow at 5pm", '
                '"What are my reminders?" or "Mark call mom as done".',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          children: [
            for (final turn in _turns) _TurnTile(turn: turn),
            if (_partial.isNotEmpty)
              ListTile(
                leading: _phase == _Phase.thinking
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.graphic_eq),
                title: Text(_partial),
              ),
          ],
        );
    }
  }

  Widget _buildInput(BuildContext context) {
    final ready = _phase == _Phase.ready;
    final listening = _phase == _Phase.listening;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: ready,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitText(),
              decoration: const InputDecoration(
                hintText: 'Type or tap the mic',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            tooltip: listening ? 'Stop listening' : 'Speak',
            onPressed: (ready && _speechAvailable) || listening
                ? _toggleListening
                : null,
            backgroundColor: listening
                ? Theme.of(context).colorScheme.error
                : null,
            child: Icon(listening ? Icons.stop : Icons.mic),
          ),
        ],
      ),
    );
  }
}

class _TurnTile extends StatelessWidget {
  const _TurnTile({required this.turn});

  final AgentTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final toolName = turn.toolName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(turn.utterance),
            ),
          ),
          const SizedBox(height: 6),
          Card(
            color: turn.isSuccess ? null : scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (toolName != null)
                    Text(
                      toolName,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  Text(turn.reply),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
