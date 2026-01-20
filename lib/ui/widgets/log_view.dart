import 'package:flutter/material.dart';

class LogView extends StatelessWidget {
  final List<String> lines;
  final VoidCallback? onClear;

  const LogView({super.key, required this.lines, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text("Log", style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (onClear != null)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text("Clear"),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 180,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(lines.join("\n")),
          ),
        ),
      ],
    );
  }
}
