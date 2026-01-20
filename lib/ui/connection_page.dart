import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _timeoutCtrl = TextEditingController();

  bool isBusy = false;
  String status = "idle";

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _unitCtrl.dispose();
    _timeoutCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<AppState>();
    _hostCtrl.text = s.host;
    _portCtrl.text = s.port.toString();
    _unitCtrl.text = s.unitId.toString();
    _timeoutCtrl.text = s.timeoutSec.toStringAsFixed(1);
  }

  Future<void> _testTcpConnect() async {
    final s = context.read<AppState>();
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 502;
    final unit = int.tryParse(_unitCtrl.text.trim()) ?? 1;
    final timeout = double.tryParse(_timeoutCtrl.text.trim().replaceAll(",", ".")) ?? s.timeoutSec;

    setState(() { isBusy = true; status = "testing..."; });

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: (timeout * 1000).round()),
      );
      socket.destroy();

      s.setHost(host);
      s.setPort(port);
      s.setUnit(unit);
      s.setTimeout(timeout);

      setState(() => status = "✓ OK ($host:$port, unit $unit)");
    } catch (e) {
      setState(() => status = "✗ ERROR: $e");
    } finally {
      setState(() => isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text("solXbus – Connection")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("TCP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(
              labelText: "Host / IP",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: "Port",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitCtrl,
                  decoration: const InputDecoration(
                    labelText: "Unit ID",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _timeoutCtrl,
            decoration: const InputDecoration(
              labelText: "Timeout (s)",
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final d = double.tryParse(v.replaceAll(",", ".")) ?? s.timeoutSec;
              context.read<AppState>().setTimeout(d.clamp(0.2, 30.0));
            },
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: isBusy ? null : _testTcpConnect,
            icon: const Icon(Icons.power),
            label: const Text("Test TCP connect"),
          ),
          const SizedBox(height: 8),
          Text("Status: $status"),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          const Text("RTU (Platzhalter)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            "RTU/Serial ist auf iPhone nur mit spezieller Hardware (ExternalAccessory/USB-Serial) möglich.\n"
            "Die UI ist da, Funktion kommt später.",
          ),
          const SizedBox(height: 12),

          AbsorbPointer(
            absorbing: true,
            child: Opacity(
              opacity: 0.55,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Serial Port",
                      hintText: "z.B. COM3 / /dev/ttyUSB0 (nicht iOS)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "Baud",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: "N",
                          items: const [
                            DropdownMenuItem(value: "N", child: Text("N")),
                            DropdownMenuItem(value: "E", child: Text("E")),
                            DropdownMenuItem(value: "O", child: Text("O")),
                          ],
                          onChanged: (_) {},
                          decoration: const InputDecoration(
                            labelText: "Parity",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "Stopbits",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
