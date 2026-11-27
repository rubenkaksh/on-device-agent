import 'package:flutter/material.dart';
import 'package:flutter_gemma_poc/agent/agent_model.dart';
import 'package:flutter_gemma_poc/main.dart';
import 'package:flutter_gemma_poc/reminders/in_memory_reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_agent_model.dart';
import 'helpers/fake_speech_input.dart';

void main() {
  testWidgets('speaking a command creates a reminder', (tester) async {
    final store = InMemoryReminderStore();
    final speech = FakeSpeechInput(nextUtterance: 'remind me to stretch');
    final model = FakeAgentModel(
      decider: (_) =>
          const ToolCallDecision('create_reminder', {'title': 'stretch'}),
    );

    await tester.pumpWidget(
      GemmaPocApp(agentModel: model, speechInput: speech, reminderStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assistant'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    expect(model.utterances, ['remind me to stretch']);
    expect(find.text('Reminder added: "stretch".'), findsOneWidget);
    expect((await store.listOpen()).single.title, 'stretch');
  });
}
