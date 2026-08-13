import 'package:flutter/material.dart';

import '../../../../core/printer/models/printer_device.dart';
import '../../../../shared/theme/app_theme.dart';
import '../printer_settings_controller.dart';

class DiscoveredDeviceTile extends StatelessWidget {
  const DiscoveredDeviceTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.connectState,
    required this.onTap,
  });

  final PrinterDevice device;
  final bool isSelected;
  final DeviceConnectState connectState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connected = isSelected && connectState == DeviceConnectState.connected;
    final connecting = isSelected && connectState == DeviceConnectState.connecting;

    return InkWell(
      onTap: connecting ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.amber : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.print_outlined, size: 18, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    device.subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (connecting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (connected)
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                  SizedBox(width: 4),
                  Text(
                    'Connected',
                    style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            else
              const Text('Connect', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
