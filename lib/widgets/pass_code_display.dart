import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The manual check-in code shown under the QR pass.
///
/// Browsers cannot scan QR codes in the web build, so the organizer types
/// this 8-character code instead. Large monospace, grouped `XXXX-XXXX`, with a
/// copy button.
class PassCodeDisplay extends StatelessWidget {
  final String code;

  const PassCodeDisplay({super.key, required this.code});

  static const String helpText =
      "If the organizer can't scan, read this code to them.";

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EFF1)),
      ),
      child: Column(
        children: [
          const Text(
            'PASS CODE',
            style: TextStyle(
              color: Color(0xFF414844),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Courier New', 'Courier'],
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Color(0xFF012D1D),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy pass code',
                icon: const Icon(Icons.copy, color: Color(0xFF0E6C4A)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pass code copied')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            helpText,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF414844), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
