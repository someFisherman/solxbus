import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/modbus/modbus_tcp.dart';
import '../state/app_state.dart';

class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  final _addrCtrl = TextEditingController(text: "0");
  final _countCtrl = TextEditingController(text: "1");
  final _valuesCtrl = TextEditingController(text: "");
  final _writeAddr23Ctrl = TextEditingController(text: "");

  int fc = 3;
  bool busy = false;

  @override
  void dispose() {
    _addrCtrl.dispose();
    _countCtrl.dispose();
    _valuesCtrl.dispose();
    _writeAddr23Ctrl.dispose();
    super.dispose();
  }

  List<int> _parseCsvInts(String s) {
    final t = s.trim();
    if (t.isEmpty) return [];
    return t
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => int.parse(e))
        .toList();
  }

  Future<void> _execute() async {
    final s = context.read<AppState>();

    final address = int.tryParse(_addrCtrl.text.trim()) ?? 0;
    final count = int.tryParse(_countCtrl.text.trim()) ?? 1;

    final timeout = Duration(milliseconds: (s.timeoutSec * 1000).round());
    final client = ModbusTcpClient(
      host: s.host,
      port: s.port,
      unitId: s.unitId,
      timeout: timeout,
      keepAlive: false,
    );

    s.addManualLog("> Manual: FC $fc, addr $address${(fc == 23 || (fc >= 1 && fc <= 4)) ? ", count $count" : ""}");

    setState(() => busy = true);

    try {
      if (fc == 1 || fc == 2 || fc == 3 || fc == 4) {
        final vals = await client.read(fc: fc, address: address, count: count);
        s.addManualLog("< READ: $vals");
      } else if (fc == 5 || fc == 6) {
        final values = _parseCsvInts(_valuesCtrl.text);
        if (values.isEmpty) throw ArgumentError("Values (CSV) fehlt (z.B. 1 oder 123).");
        await client.writeSingle(fc: fc, address: address, valueRaw: values.first);
        s.addManualLog("< WRITE ok");
      } else if (fc == 15 || fc == 16) {
        final values = _parseCsvInts(_valuesCtrl.text);
        if (values.isEmpty) throw ArgumentError("Values (CSV) fehlt (z.B. 1,0,1 oder 10,20).");
        await client.writeMultiple(fc: fc, address: address, valuesRaw: values);
        s.addManualLog("< WRITE multiple ok (${values.length} values)");
      } else if (fc == 23) {
        final writeAddr = int.tryParse(_writeAddr23Ctrl.text.trim());
        if (writeAddr == null) throw ArgumentError("FC23 write address fehlt.");
        final values = _parseCsvInts(_valuesCtrl.text);
        if (values.isEmpty) throw ArgumentError("FC23 values (CSV) fehlt.");
        final rd = await client.readWrite23(
          readAddress: address,
          readCount: count,
          writeAddress: writeAddr,
          writeValuesRaw: values,
        );
        s.addManualLog("< READ part: $rd");
      } else {
        throw ArgumentError("Unsupported FC: $fc");
      }
    } catch (e) {
      s.addManualLog("[ERROR] $e");
    } finally {
      await client.close();
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    final needsCount = (fc == 1 || fc == 2 || fc == 3 || fc == 4 || fc == 23);
    final needsValues = (fc == 5 || fc == 6 || fc == 15 || fc == 16 || fc == 23);
    final needsWriteAddr23 = (fc == 23);

    return Scaffold(
      appBar: AppBar(
        title: const Text("solXbus – Manual"),
        actions: [
          IconButton(
            onPressed: () => context.read<AppState>().clearManualLog(),
            icon: const Icon(Icons.delete_outline),
            tooltip: "Clear log",
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: fc,
                          items: const [1,2,3,4,5,6,15,16,23]
                              .map((v) => DropdownMenuItem(value: v, child: Text("FC $v")))
                              .toList(),
                          onChanged: busy ? null : (v) => setState(() => fc = v ?? 3),
                          decoration: const InputDecoration(
                            labelText: "Function Code",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _addrCtrl,
                          decoration: const InputDecoration(
                            labelText: "Address",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !busy,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (needsCount)
                    TextField(
                      controller: _countCtrl,
                      decoration: const InputDecoration(
                        labelText: "Count (reads / FC23)",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !busy,
                    ),

                  if (needsCount) const SizedBox(height: 12),

                  if (needsWriteAddr23)
                    TextField(
                      controller: _writeAddr23Ctrl,
                      decoration: const InputDecoration(
                        labelText: "FC23 write address",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !busy,
                    ),

                  if (needsWriteAddr23) const SizedBox(height: 12),

                  if (needsValues)
                    TextField(
                      controller: _valuesCtrl,
                      decoration: InputDecoration(
                        labelText: "Values (CSV)",
                        hintText: fc == 5 ? "0 oder 1" : "z.B. 10,20,30",
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.text,
                      enabled: !busy,
                    ),

                  if (needsValues) const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : _execute,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(busy ? "Running..." : "Execute"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text("Target: ${s.host}:${s.port}  unit=${s.unitId}  timeout=${s.timeoutSec.toStringAsFixed(1)}s"),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text("Log:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              s.manualLog.isEmpty ? "—" : s.manualLog.join("\n"),
              style: const TextStyle(fontFamily: "monospace", fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
