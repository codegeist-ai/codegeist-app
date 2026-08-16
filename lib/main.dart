import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';

const _modelRevision = 'ce073afd34b725825b19089cec1a9e7b884b2fbe';
const _modelFile = 'gguf/codegeist-llm-Q4_K_M.gguf';
const _modelSha256 =
    'be7824de2fc34955d640e30e41e92dd66206e86ab7fe027084015a9b7da44fce';
const _contextSize = 2048;
const _maxResponseTokens = 256;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.modelLoadOverride});

  final Future<void> Function()? modelLoadOverride;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _ChatPage(modelLoadOverride: modelLoadOverride),
    );
  }
}

/// Owns the one-screen model lifecycle and in-memory conversation.
///
/// No platform or network work starts until the user requests the model, which
/// keeps normal launch, widget tests, and the Android smoke test lightweight.
class _ChatPage extends StatefulWidget {
  const _ChatPage({this.modelLoadOverride});

  final Future<void> Function()? modelLoadOverride;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];

  LlamaEngine? _engine;
  ChatSession? _session;
  ModelDownloadCancelToken? _downloadCancelToken;
  bool _isLoading = false;
  bool _isGenerating = false;
  int? _downloadPercent;
  String? _error;

  /// Requires an explicit Alpha Preview acknowledgement before any model work.
  ///
  /// The optional callback keeps widget tests independent of platform channels,
  /// network access, and native inference libraries. Normal app builds always
  /// use the real model loader.
  Future<void> _requestModelLoad() async {
    if (_isLoading || _engine != null) return;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Codegeist Alpha Preview'),
        content: const Text(
          'Codegeist uses a small experimental model that runs locally on this '
          'device. It can produce inaccurate, incomplete, unsafe, or offensive '
          'text.\n\n'
          'The first load downloads approximately 1.11 GB. Your prompts and '
          'generated responses stay on this device.\n\n'
          'Do not rely on its output as professional, legal, medical, financial, '
          'security, or other expert advice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;

    final override = widget.modelLoadOverride;
    if (override != null) {
      await override();
      return;
    }
    await _loadModel();
  }

  /// Resolves the immutable GGUF into private storage, verifies it, and starts
  /// a CPU-only inference session. Failed attempts dispose their native state
  /// and leave the same action available for a clean retry.
  Future<void> _loadModel() async {
    if (_isLoading || _engine != null) return;

    final cancelToken = ModelDownloadCancelToken();
    _downloadCancelToken = cancelToken;
    setState(() {
      _isLoading = true;
      _downloadPercent = null;
      _error = null;
    });
    debugPrint(
      'event=model_load status=started revision=$_modelRevision backend=cpu',
    );

    final engine = LlamaEngine(LlamaBackend());
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      await engine.loadModelSource(
        ModelSource.huggingFace(
          repoId: 'codegeist/codegeist-llm',
          revision: _modelRevision,
          filePath: _modelFile,
        ),
        modelParams: const ModelParams(
          contextSize: _contextSize,
          gpuLayers: 0,
          preferredBackend: GpuBackend.cpu,
        ),
        options: ModelLoadOptions(
          cacheDirectory: supportDirectory.path,
          sha256: _modelSha256,
          cancelToken: cancelToken,
        ),
        onProgress: (progress) {
          final percent = progress.fraction == null
              ? null
              : (progress.fraction! * 100).floor();
          if (!mounted || percent == _downloadPercent) return;
          setState(() => _downloadPercent = percent);
        },
      );

      if (!mounted) {
        await engine.dispose();
        return;
      }
      setState(() {
        _engine = engine;
        _session = ChatSession(engine, maxContextTokens: _contextSize);
        _isLoading = false;
        _downloadPercent = 100;
      });
      debugPrint(
        'event=model_load status=completed revision=$_modelRevision '
        'context_tokens=$_contextSize backend=cpu',
      );
    } catch (error) {
      await engine.dispose();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            'Could not load the model. Check storage and connection, '
            'then try again.';
      });
      debugPrint(
        'event=model_load status=failed error_type=${error.runtimeType}',
      );
    } finally {
      if (identical(_downloadCancelToken, cancelToken)) {
        _downloadCancelToken = null;
      }
    }
  }

  /// Adds one user turn and streams the assistant text into its visible bubble.
  Future<void> _send() async {
    final session = _session;
    final prompt = _inputController.text.trim();
    if (session == null || prompt.isEmpty || _isGenerating) return;

    final assistantMessage = _ChatMessage(isUser: false, text: '');
    _inputController.clear();
    setState(() {
      _error = null;
      _isGenerating = true;
      _messages.add(_ChatMessage(isUser: true, text: prompt));
      _messages.add(assistantMessage);
    });
    _scrollToEnd();
    debugPrint(
      'event=chat_generation status=started input_characters=${prompt.length}',
    );

    try {
      await for (final chunk in session.create(
        [LlamaTextContent(prompt)],
        params: const GenerationParams(maxTokens: _maxResponseTokens),
        enableThinking: false,
      )) {
        if (chunk.choices.isEmpty) continue;
        final text = chunk.choices.first.delta.content;
        if (!mounted || text == null || text.isEmpty) continue;
        setState(() => assistantMessage.text += text);
        _scrollToEnd();
      }
      if (!mounted) return;
      if (assistantMessage.text.isEmpty) {
        setState(() {
          _messages.remove(assistantMessage);
          _error = 'The model returned no text. Try another message.';
        });
      }
      debugPrint(
        'event=chat_generation status=completed '
        'output_characters=${assistantMessage.text.length}',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (assistantMessage.text.isEmpty) {
          _messages.remove(assistantMessage);
        }
        _error = 'Could not generate a response. Try again.';
      });
      debugPrint(
        'event=chat_generation status=failed error_type=${error.runtimeType}',
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _downloadCancelToken?.cancel();
    final engine = _engine;
    if (engine != null) {
      engine.cancelGeneration();
      unawaited(engine.dispose());
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _session == null ? _buildModelLoader() : _buildChat(),
      ),
    );
  }

  Widget _buildModelLoader() {
    final percent = _downloadPercent;
    final status = percent == null
        ? 'Preparing model...'
        : percent < 100
        ? 'Downloading model: $percent%'
        : 'Verifying and loading model...';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _CodegeistLogo(width: 240),
            const SizedBox(height: 40),
            Text(
              'Local chat',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              '1.11 GB model download. Runs locally after the first load.',
              textAlign: TextAlign.center,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 28),
              LinearProgressIndicator(
                key: const Key('model-progress'),
                value: percent == null ? null : percent / 100,
              ),
              const SizedBox(height: 12),
              Text(status),
            ] else ...[
              const SizedBox(height: 28),
              FilledButton(
                key: const Key('load-model'),
                onPressed: _requestModelLoad,
                child: Text(_error == null ? 'Load model' : 'Try again'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: _CodegeistLogo(width: 180),
        ),
        const Divider(height: 1),
        Expanded(
          child: _messages.isEmpty
              ? const Center(child: Text('Start a local conversation.'))
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: _messages[index]),
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat-input'),
                  controller: _inputController,
                  enabled: !_isGenerating,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Message Codegeist',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: _isGenerating ? null : _send,
                icon: _isGenerating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CodegeistLogo extends StatelessWidget {
  const _CodegeistLogo({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/codegeist-logo-horizontal-light.svg',
      width: width,
      semanticsLabel: 'codegeist',
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.isUser, required this.text});

  final bool isUser;
  String text;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.text.isEmpty ? '...' : message.text),
      ),
    );
  }
}
