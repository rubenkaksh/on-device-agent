import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma_poc/services/gemma_service.dart';

import 'helpers/lifecycle_inference_session.dart';

void main() {
  test(
    'a stopped first generation is fully drained before the second prompt',
    () async {
      final session = LifecycleInferenceSession();
      final chat = InferenceChat(
        sessionCreator: () async => session,
        maxTokens: 1024,
      );
      await chat.initSession();
      final service = GemmaService.forTesting(chat);

      final firstResponse = await service.sendMessageStream('first').toList();
      final secondResponse = await service.sendMessageStream('second').toList();

      expect(firstResponse, ['hello']);
      expect(secondResponse, ['second']);
      expect(session.stopCalls, 1);
    },
  );
}
