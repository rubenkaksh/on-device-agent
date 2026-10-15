import 'package:flutter_gemma_poc/services/llm_service_factory.dart';
import 'package:flutter_gemma_poc/services/gemma_service.dart';
import 'package:flutter_gemma_poc/services/nobodywho_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_nobodywho_chat.dart';

void main() {
  group('NobodyWhoService', () {
    test('streams tokens and clears isGenerating when done', () async {
      final chat = FakeNobodyWhoChat([
        ['Hel', 'lo'],
      ]);
      final service = NobodyWhoService.forTesting(chat);

      final stream = service.sendMessageStream('hi');
      expect(service.isGenerating, isTrue);
      final tokens = await stream.toList();

      expect(tokens, ['Hel', 'lo']);
      expect(chat.prompts, ['hi']);
      expect(service.isGenerating, isFalse);
    });

    test('strips literal stop tokens and halts generation', () async {
      final chat = FakeNobodyWhoChat([
        ['Hi', '<end_of_turn>', 'leaked'],
      ]);
      final service = NobodyWhoService.forTesting(chat);

      final tokens = await service.sendMessageStream('x').toList();

      expect(tokens, ['Hi']);
      expect(chat.stopCalls, 1);
    });

    test('stopGeneration unwinds before the next prompt', () async {
      final chat = FakeNobodyWhoChat([
        ['a', 'b', 'c', 'd'],
        ['second'],
      ]);
      final service = NobodyWhoService.forTesting(chat);

      final first = <String>[];
      final sub = service.sendMessageStream('one').listen(first.add);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await service.stopGeneration();
      await sub.cancel();

      expect(service.isGenerating, isFalse);
      expect(chat.stopCalls, 1);
      expect(first.length, lessThan(4));

      final second = await service.sendMessageStream('two').toList();
      expect(second, ['second']);
    });

    test('stopGeneration is a no-op when idle', () async {
      final chat = FakeNobodyWhoChat([]);
      final service = NobodyWhoService.forTesting(chat);

      await service.stopGeneration();

      expect(chat.stopCalls, 0);
    });

    test('rejects a second prompt while generating', () async {
      final chat = FakeNobodyWhoChat([
        ['a', 'b'],
      ]);
      final service = NobodyWhoService.forTesting(chat);

      final done = service.sendMessageStream('one').toList();

      expect(() => service.sendMessageStream('two'), throwsStateError);
      await done;
    });

    test('forwards engine errors to the stream', () async {
      final chat = FakeNobodyWhoChat([
        ['a', 'b'],
      ])..errorAfterFirstToken = StateError('boom');
      final service = NobodyWhoService.forTesting(chat);

      await expectLater(
        service.sendMessageStream('x'),
        emitsInOrder(['a', emitsError(isA<StateError>()), emitsDone]),
      );
      expect(service.isGenerating, isFalse);
    });

    test('clearChat resets history and dispose releases the chat', () async {
      final chat = FakeNobodyWhoChat([]);
      final service = NobodyWhoService.forTesting(chat);

      await service.clearChat();
      await service.dispose();

      expect(chat.resetCalls, 1);
      expect(service.isModelLoaded, isFalse);
      expect(() => service.sendMessageStream('x'), throwsStateError);
    });

    test('installModel maps download bytes to percent', () async {
      final chat = FakeNobodyWhoChat([]);
      final service = NobodyWhoService.forTesting(
        null,
        loader:
            (path, {required contextSize, required onDownloadProgress}) async {
              onDownloadProgress(50, 200);
              onDownloadProgress(200, 200);
              return chat;
            },
      );
      final progress = <int>[];

      await service.installModel(modelUrl: 'x', onProgress: progress.add);

      expect(progress, [25, 100]);
      expect(service.isModelLoaded, isTrue);
    });

    test('installModel requires initialize()', () async {
      final service = NobodyWhoService();

      await expectLater(service.installModel(modelUrl: 'x'), throwsStateError);
    });
  });

  group('NobodyWhoService cache', () {
    test('isModelInstalled matches the cached file name', () async {
      final service = NobodyWhoService.forTesting(
        null,
        cachedModels: () => [
          ('/cache/models/gemma-3n-E2B-it-Q4_K_M.gguf', BigInt.one),
        ],
      );

      expect(await service.isModelInstalled(), isTrue);
    });

    test('isModelInstalled is false for other or no cached files', () async {
      final other = NobodyWhoService.forTesting(
        null,
        cachedModels: () => [('/cache/models/other.gguf', BigInt.one)],
      );
      final empty = NobodyWhoService.forTesting(null);

      expect(await other.isModelInstalled(), isFalse);
      expect(await empty.isModelInstalled(), isFalse);
    });

    test('isModelInstalled survives a cache read error', () async {
      final service = NobodyWhoService.forTesting(
        null,
        cachedModels: () => throw StateError('unreadable'),
      );

      expect(await service.isModelInstalled(), isFalse);
    });
  });

  group('createLlmService', () {
    test('defaults to gemma without .env', () {
      expect(createLlmService(), isA<GemmaService>());
    });

    test('selects the requested backend', () {
      expect(createLlmService(LlmBackend.nobodywho), isA<NobodyWhoService>());
      expect(createLlmService(LlmBackend.gemma), isA<GemmaService>());
    });
  });
}
