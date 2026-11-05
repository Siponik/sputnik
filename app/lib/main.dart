import 'package:flutter/material.dart';

// Заглушка: настоящий интерфейс (дизайн G) строится по docs/flutter-architecture.md.
void main() => runApp(const SputnikApp());

class SputnikApp extends StatelessWidget {
  const SputnikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Спутник',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('Спутник'))),
    );
  }
}
