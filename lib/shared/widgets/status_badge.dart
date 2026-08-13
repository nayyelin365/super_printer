import 'package:flutter/material.dart';

import '../../core/printer/label_printer.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final PrinterConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      PrinterConnectionStatus.connected => (AppTheme.success, 'Connected'),
      PrinterConnectionStatus.connecting => (AppTheme.amber, 'Connecting...'),
      PrinterConnectionStatus.disconnected => (AppTheme.danger, 'Disconnected'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
