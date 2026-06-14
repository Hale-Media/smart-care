import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// A small coloured pill used for severity / status / risk bands.
class StatusPill extends StatelessWidget {
  final String label;
  final String severity; // critical/high/medium/low/info/normal
  const StatusPill({super.key, required this.label, this.severity = 'info'});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
