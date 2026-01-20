import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/net/ip_range.dart';
import '../state/app_state.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool useCidr = true;

  final _cidrCtrl = TextEditingController(text: "192.168.1.0/24");
  final _startCtrl = TextEditingController(text: "192.168.1.1");
  final _endCtrl = TextEditingController(text: "192.168.1.254");

  final _portCtrl = TextEditingController(text: "502");
  final _timeoutMsCtrl = TextEditingController(text: "250");
  final _concurrencyCtrl = TextEditingController(text: "40");

  bool running = false;
  String status = "idle";
  final List<String> found = [];

  @override
  void dispose() {
    _cidrCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _portCtrl.dispose();
    _timeoutMsCtrl.dispose();
    _concurrencyCtrl.dispose();
    super.dispose();
  }

  Future<bool> _probe(String ip, int port, Duration timeout) async {
    try {
      final s = await Socket.connect(ip, port, timeout: timeout);
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startScan() async {
    if (running) return;

    final port = int.tryParse(_portCtrl.text.trim()) ?? 502;
    final timeoutMs = int.tryParse(_timeoutMsCtrl.text.trim()) ?? 250;
    final concurrency = (int.tryParse(_concurrencyCtrl.text.trim()) ?? 40).clamp(1, 200);

    List<String> ips;
    try {
      ips = useCidr
          ? expandCidr(_cidrCtrl.text.trim())
          : expandStartEnd(_startCtrl.text.trim(), _endCtrl.text.trim());
    } catch (e) {
      setState(() => status = "✗ Input Error: $e");
      return;
    }

    final timeout = Duration(milliseconds: timeoutMs);

    setState(() {
      running = true;
      status = "Scanning ${ips.length} IPs...";
      found.clear();
    });

    int done = 0;
    final sem = _Semaphore(concurrency);
    final tasks = <Future<void>>[];

    for (final ip in ips) {
      if (!mounted) break;
      if (!running) break;

      await sem.acquire();
      if (!running) {
        sem.release();
        break;
      }

      final task = () async {
        try {
          final ok = await _probe(ip, port, timeout);
          if (!mounted || !running) return;

          if (ok) {
            setState(() => found.add(ip));
            // optional log
            context.read<AppState>().addScanLog("FOUND: $ip:$port");
          }
        } finally {
          done += 1;
          if (mounted && (done % 25 == 0 || done == ips.length)) {
            setState(() => status = "Progress: $done/${ips.length}");
          }
          sem.release();
        }
      }();

      tasks.add(task);
    }

    await Future.wait(tasks);

    if (!mounted) return;
    setState(() {
      running = false;
      status = "✓ Done. Found ${found.length} device(s) with port open.";
    });
  }

  void _stopScan() {
    if (!running) return;
    setState(() {
      running = false;
      status = "Stopping...";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("solXbus – Scan (TCP/502)")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text("CIDR")),
              ButtonSegment(value: false, label: Text("Start–End")),
            ],
            selected: {useCidr},
            onSelectionChanged: running ? null : (s) => setState(() => useCidr = s.first),
          ),
          const SizedBox(height: 12),

          if (useCidr)
            TextField(
              controller: _cidrCtrl,
              enabled: !running,
              decoration: const InputDecoration(
                labelText: "IP-Range (CIDR)",
                hintText: "z.B. 192.168.1.0/24",
                border: OutlineInputBorder(),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startCtrl,
                    enabled: !running,
                    decoration: const InputDecoration(
                      labelText: "Start IP",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endCtrl,
                    enabled: !running,
                    decoration: const InputDecoration(
                      labelText: "End IP",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _portCtrl,
                  enabled: !running,
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
                  controller: _timeoutMsCtrl,
                  enabled: !running,
                  decoration: const InputDecoration(
                    labelText: "Timeout (ms)",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _concurrencyCtrl,
                  enabled: !running,
                  decoration: const InputDecoration(
                    labelText: "Parallel",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: running ? null : _startScan,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Start Scan"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: running ? _stopScan : null,
                  icon: const Icon(Icons.stop),
                  label: const Text("Stop"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text("Status: $status"),

          const SizedBox(height: 16),
          const Text(
            "Gefundene Geräte (Port offen):",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (found.isEmpty)
            const Text("Noch nichts gefunden.")
          else
            ...found.map(
              (ip) => Card(
                child: ListTile(
                  leading: const Icon(Icons.device_hub),
                  title: Text(ip),
                  subtitle: const Text("Port offen"),
                  onTap: () {
                    context.read<AppState>().setHost(ip);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Host übernommen: $ip")),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Semaphore {
  int _count;
  final List<Completer<void>> _waiters = [];

  _Semaphore(this._count);

  Future<void> acquire() {
    if (_count > 0) {
      _count -= 1;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
      return;
    }
    _count += 1;
  }
}
