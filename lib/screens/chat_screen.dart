import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gemma_poc/services/gemma_service.dart';

/// Chat screen for on-device Gemma inference.
///
/// Shows model loading progress, message list with streaming tokens,
/// and a text input for user prompts.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.gemmaService});

  final GemmaService gemmaService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];

  bool _isLoadingModel = false;
  bool _isGenerating = false;
  String _loadingStatus = '';
  int _downloadProgress = 0;
  String? _error;

  /// Subscription to the active generation stream — null when idle.
  StreamSubscription<String>? _generationSubscription;

  // Default Gemma 2B model URL (MediaPipe's hosted .task file)
  static const _defaultModelUrl =
      'https://huggingface.co/google/gemma-3n-E2B-it-litert-lm/resolve/main/gemma-3n-E2B-it-int4.litertlm';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _loadingStatus = 'Initializing...';
      _error = null;
    });

    try {
      await widget.gemmaService.initialize();

      final installed = await widget.gemmaService.isModelInstalled();
      if (installed) {
        setState(() => _loadingStatus = 'Loading model...');
        await widget.gemmaService.loadChat();
        setState(() {
          _isLoadingModel = false;
          _loadingStatus = '';
        });
      } else {
        setState(() {
          _isLoadingModel = false;
          _loadingStatus = '';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Initialization failed: $e';
        _isLoadingModel = false;
        _loadingStatus = '';
      });
    }
  }

  Future<void> _installAndLoadModel() async {
    setState(() {
      _isLoadingModel = true;
      _downloadProgress = 0;
      _loadingStatus = 'Downloading model... (this may take a while)';
      _error = null;
    });

    try {
      await widget.gemmaService.installModel(
        modelUrl: _defaultModelUrl,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
            _loadingStatus = 'Downloading model... $progress%';
          });
        },
      );

      setState(() => _loadingStatus = 'Loading model into memory...');
      await widget.gemmaService.loadChat();

      setState(() {
        _isLoadingModel = false;
        _loadingStatus = '';
      });
    } catch (e) {
      setState(() {
        _error = 'Model install failed: $e';
        _isLoadingModel = false;
        _loadingStatus = '';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(_ChatMessage(text: '', isUser: false, isStreaming: true));
      _isGenerating = true;
      _error = null;
    });

    _scrollToBottom();

    final buffer = StringBuffer();
    final stream = widget.gemmaService.sendMessageStream(text);

    _generationSubscription = stream.listen(
      (token) {
        buffer.write(token);
        if (mounted) {
          setState(() {
            _messages.last = _ChatMessage(
              text: buffer.toString(),
              isUser: false,
              isStreaming: true,
            );
          });
          _scrollToBottom();
        }
      },
      onDone: () {
        _finalizeGeneration(buffer.toString());
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _messages.last = _ChatMessage(
              text: buffer.isEmpty
                  ? 'Error: $error'
                  : buffer.toString(),
              isUser: false,
              isStreaming: false,
            );
            _isGenerating = false;
            _error = 'Generation failed: $error';
          });
        }
        _generationSubscription = null;
      },
      cancelOnError: false,
    );
  }

  /// Finalize the streaming message — called on normal completion.
  void _finalizeGeneration(String text) {
    if (mounted) {
      setState(() {
        _messages.last = _ChatMessage(
          text: text,
          isUser: false,
          isStreaming: false,
        );
        _isGenerating = false;
      });
    }
    _generationSubscription = null;
  }

  /// Stop the current generation — bound to the Stop button.
  Future<void> _stopGeneration() async {
    await _generationSubscription?.cancel();
    _generationSubscription = null;
    await widget.gemmaService.stopGeneration();

    // Mark the last message as no longer streaming.
    if (mounted && _messages.isNotEmpty) {
      setState(() {
        final last = _messages.last;
        _messages.last = _ChatMessage(
          text: last.text,
          isUser: last.isUser,
          isStreaming: false,
        );
        _isGenerating = false;
      });
    }
  }

  Future<void> _clearChat() async {
    await widget.gemmaService.clearChat();
    setState(() {
      _messages.clear();
      _error = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _generationSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    widget.gemmaService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemma Chat'),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear chat',
              onPressed: _isGenerating ? null : _clearChat,
            ),
        ],
      ),
      body: Column(
        children: [
          // Model status / install section
          if (!widget.gemmaService.isModelLoaded && !_isLoadingModel)
            _ModelInstallCard(onInstall: _installAndLoadModel, error: _error),

          // Loading indicator
          if (_isLoadingModel)
            _LoadingCard(status: _loadingStatus, progress: _downloadProgress),

          // Error banner
          if (_error != null && widget.gemmaService.isModelLoaded)
            _ErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),

          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      widget.gemmaService.isModelLoaded
                          ? 'Send a message to start chatting'
                          : 'Install the model to begin',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _MessageBubble(message: msg);
                    },
                  ),
          ),

          // Input area
          if (widget.gemmaService.isModelLoaded)
            _InputBar(
              controller: _controller,
              isGenerating: _isGenerating,
              onSend: _sendMessage,
              onStop: _stopGeneration,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  final String text;
  final bool isUser;
  final bool isStreaming;
}

class _ModelInstallCard extends StatelessWidget {
  const _ModelInstallCard({required this.onInstall, this.error});

  final VoidCallback onInstall;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Gemma 2B On-Device', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Download and run the Gemma 2B model locally. '
              'No data leaves your device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onInstall,
              icon: const Icon(Icons.download),
              label: const Text('Download Model (~2 GB)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.status, required this.progress});

  final String status;
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress > 0 ? progress / 100.0 : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MaterialBanner(
      content: Text(
        message,
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
      backgroundColor: theme.colorScheme.errorContainer,
      actions: [TextButton(onPressed: onDismiss, child: const Text('DISMISS'))],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.text.isEmpty && message.isStreaming)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            if (message.isStreaming && message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isGenerating,
              decoration: InputDecoration(
                hintText: isGenerating ? 'Generating...' : 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isGenerating ? onStop : onSend,
            icon: isGenerating
                ? const Icon(Icons.stop)
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
