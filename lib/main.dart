import 'package:flutter/material.dart';
import 'package:flutter_gemma_poc/screens/chat_screen.dart';
import 'package:flutter_gemma_poc/services/gemma_service.dart';

void main() {
  runApp(const GemmaPocApp());
}

/// Root widget for the Gemma POC app.
class GemmaPocApp extends StatelessWidget {
  const GemmaPocApp({super.key});

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
      home: ChatScreen(gemmaService: GemmaService()),
    );
  }
}
