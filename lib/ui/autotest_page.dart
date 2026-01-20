import 'package:flutter/material.dart';

class AutoTestPage extends StatelessWidget {
  const AutoTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("solXbus – Auto-Test")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Auto-Test als nächster Schritt:\n"
          "- JSON Plan einfügen\n"
          "- Steps auswählen\n"
          "- Reads/Writes ausführen\n"
          "- Result Table + CSV Export",
        ),
      ),
    );
  }
}
