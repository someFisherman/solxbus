import 'package:flutter/material.dart';

import 'connection_page.dart';
import 'manual_page.dart';
import 'scan_page.dart';
import 'autotest_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int idx = 0;

  final pages = const [
    ConnectionPage(),
    ManualPage(),
    ScanPage(),
    AutoTestPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (v) => setState(() => idx = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.link), label: "Connection"),
          NavigationDestination(icon: Icon(Icons.handyman), label: "Manual"),
          NavigationDestination(icon: Icon(Icons.search), label: "Scan"),
          NavigationDestination(icon: Icon(Icons.playlist_play), label: "Auto-Test"),
        ],
      ),
    );
  }
}
