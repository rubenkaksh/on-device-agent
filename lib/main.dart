import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma_poc/agent/agent.dart';
import 'package:flutter_gemma_poc/agent/agent_log.dart';
import 'package:flutter_gemma_poc/agent/agent_model.dart';
import 'package:flutter_gemma_poc/agent/agent_tool.dart';
import 'package:flutter_gemma_poc/agent/models/agent_model_factory.dart';
import 'package:flutter_gemma_poc/reminders/reminder.dart';
import 'package:flutter_gemma_poc/reminders/reminder_store_factory.dart';
import 'package:flutter_gemma_poc/reminders/reminder_tools.dart';
import 'package:flutter_gemma_poc/screens/agent_screen.dart';
import 'package:flutter_gemma_poc/screens/chat_screen.dart';
import 'package:flutter_gemma_poc/services/llm_service.dart';
import 'package:flutter_gemma_poc/services/llm_service_factory.dart';
import 'package:flutter_gemma_poc/speech/speech_input.dart';
import 'package:flutter_gemma_poc/speech/speech_input_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  runApp(const GemmaPocApp());
}

/// Root widget. Every backend is injectable so tests (or a different build)
/// can plug in other models, speech engines or reminder stores.
class GemmaPocApp extends StatelessWidget {
  const GemmaPocApp({
    super.key,
    this.llmService,
    this.agentModel,
    this.speechInput,
    this.reminderStore,
  });

  /// Chat POC backend; defaults to `LLM_BACKEND` from `.env`.
  final LlmService? llmService;

  /// Agent model; defaults to `AGENT_MODEL` from `.env`.
  final AgentModel? agentModel;

  /// Speech-to-text; defaults to `SPEECH_INPUT` from `.env`.
  final SpeechInput? speechInput;

  /// Reminder storage; defaults to Apple Reminders on iOS.
  final ReminderStore? reminderStore;

  @override
  Widget build(BuildContext context) {
    final agent = Agent(
      model: agentModel ?? createAgentModel(),
      onLog: appendAgentLog,
      tools: ToolRegistry(
        reminderTools(reminderStore ?? createReminderStore()),
      ),
    );
    return MaterialApp(
      title: 'On-Device Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) => AgentScreen(
          agent: agent,
          speech: speechInput ?? createSpeechInput(),
          onOpenChat: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ChatScreen(llmService: llmService ?? createLlmService()),
            ),
          ),
        ),
      ),
    );
  }
}
