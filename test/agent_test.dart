import 'package:flutter_gemma_poc/agent/agent.dart';
import 'package:flutter_gemma_poc/agent/agent_model.dart';
import 'package:flutter_gemma_poc/agent/agent_tool.dart';
import 'package:flutter_gemma_poc/reminders/in_memory_reminder_store.dart';
import 'package:flutter_gemma_poc/reminders/reminder_tools.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_agent_model.dart';

void main() {
  // Friday 2026-11-20 17:46.
  final now = DateTime(2026, 11, 20, 17, 46);
  DateTime clock() => now;

  late InMemoryReminderStore store;

  Agent agentWith(List<AgentDecision> decisions) => Agent(
    model: FakeAgentModel(decisions: decisions),
    tools: ToolRegistry(reminderTools(store, clock: clock)),
    clock: clock,
  );

  setUp(() => store = InMemoryReminderStore());

  test('prepare installs a missing model and loads every tool', () async {
    final model = FakeAgentModel()..installed = false;
    final agent = Agent(
      model: model,
      tools: ToolRegistry(reminderTools(store, clock: clock)),
    );

    await agent.prepare();

    expect(model.installCalls, 1);
    expect(model.loadedTools.map((t) => t.name), [
      'create_reminder',
      'list_reminders',
      'complete_reminder',
    ]);
  });

  test('create_reminder resolves the spoken due time', () async {
    final agent = agentWith([
      const ToolCallDecision('create_reminder', {
        'title': 'call mom',
        'due': 'tomorrow at 5pm',
      }),
    ]);

    final turn = await agent.handle('remind me to call mom tomorrow at 5pm');

    expect(turn.isSuccess, isTrue);
    expect(turn.reply, contains('tomorrow at 5:00 PM'));
    final open = await store.listOpen();
    expect(open.single.title, 'call mom');
    expect(open.single.due, DateTime(2026, 11, 21, 17));
  });

  test('create_reminder recovers a time left inside the title', () async {
    final agent = agentWith([
      const ToolCallDecision('create_reminder', {
        'title': 'buy milk in 20 minutes',
      }),
    ]);

    await agent.handle('remind me to buy milk in 20 minutes');

    final open = await store.listOpen();
    expect(open.single.title, 'buy milk');
    expect(open.single.due, now.add(const Duration(minutes: 20)));
  });

  test('list then complete a reminder', () async {
    await store.create(title: 'call mom', due: DateTime(2026, 11, 21, 17));
    await store.create(title: 'pay rent');
    final agent = agentWith([
      const ToolCallDecision('list_reminders', {}),
      const ToolCallDecision('complete_reminder', {'title': 'Call Mom'}),
    ]);

    final listed = await agent.handle('what are my reminders');
    expect(listed.reply, contains('2 open reminders'));
    expect(listed.reply, contains('call mom — tomorrow at 5:00 PM'));

    final done = await agent.handle('mark call mom as done');
    expect(done.isSuccess, isTrue);
    expect((await store.listOpen()).map((r) => r.title), ['pay rent']);
  });

  test('unknown tool and text replies are surfaced, not thrown', () async {
    final agent = agentWith([
      const ToolCallDecision('order_pizza', {}),
      const TextDecision('I can only manage reminders for now.'),
    ]);

    final unknown = await agent.handle('order a pizza');
    expect(unknown.isSuccess, isFalse);

    final text = await agent.handle('tell me a joke');
    expect(text.reply, 'I can only manage reminders for now.');
  });
}
