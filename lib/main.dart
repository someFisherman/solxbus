import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/home_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const SolXBusApp(),
    ),
  );
}

class SolXBusApp extends StatelessWidget {
  const SolXBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'solXbus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}
