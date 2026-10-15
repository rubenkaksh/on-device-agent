import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma_poc/screens/chat_screen.dart';
import 'package:flutter_gemma_poc/services/llm_service.dart';
import 'package:flutter_gemma_poc/services/llm_service_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  runApp(const GemmaPocApp());
}

/// Root widget for the Gemma POC app.
class GemmaPocApp extends StatelessWidget {
  const GemmaPocApp({super.key, this.llmService});

  /// Backend override for tests; defaults to the `LLM_BACKEND` from `.env`.
  final LlmService? llmService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma Chat POC',
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
      home: ChatScreen(llmService: llmService ?? createLlmService()),
    );
  }
}
