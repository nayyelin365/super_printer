import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/printer/models/connection_type.dart';
import '../../../core/printer/models/label_size.dart';
import '../../../shared/theme/app_theme.dart';
import 'printer_settings_controller.dart';
import 'widgets/discovered_device_tile.dart';

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printerSetupControllerProvider);
    final controller = ref.read(printerSetupControllerProvider.notifier);

    ref.listen(printerSetupControllerProvider, (previous, next) {
      if (next.saved && previous?.saved != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer configuration saved.')),
        );
      }
    });

    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Printer Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),

                _FieldLabel('Name'),
                TextFormField(
                  initialValue: state.name,
                  decoration: const InputDecoration(hintText: 'Name'),
                  onChanged: controller.setName,
                ),
                const SizedBox(height: 16),

                _FieldLabel('Printer Connection Type'),
                DropdownButtonFormField<PrinterConnectionType>(
                  initialValue: state.connectionType,
                  items: PrinterConnectionType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) controller.setConnectionType(v);
                  },
                ),
                const SizedBox(height: 16),

                _FieldLabel('Printer Model'),
                DropdownButtonFormField<String>(
                  initialValue: state.printerModelId,
                  items: ref
                      .watch(printerModelCatalogProvider)
                      .map((m) => DropdownMenuItem(value: m.id, child: Text(m.displayName)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) controller.setPrinterModel(v);
                  },
                ),
                const SizedBox(height: 16),

                _FieldLabel('Printer'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        state.connectionType == PrinterConnectionType.bluetooth
                            ? 'Search for nearby Bluetooth printers'
                            : 'Search for connected USB printers',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: state.isSearching ? null : controller.search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: state.isSearching
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search, size: 16),
                      label: Text(state.isSearching ? 'Searching...' : 'Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                    ),
                  ),

                if (state.discoveredDevices.isEmpty && !state.isSearching)
                  const Text(
                    'No printers found yet. Tap Search to scan.',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  )
                else
                  ...state.discoveredDevices.map(
                    (d) => DiscoveredDeviceTile(
                      device: d,
                      isSelected: state.selectedDevice == d,
                      connectState: state.connectState,
                      onTap: () => controller.connectTo(d),
                    ),
                  ),
                const SizedBox(height: 8),

                _FieldLabel('DPI'),
                DropdownButtonFormField<int>(
                  initialValue: state.dpi,
                  items: const [203, 300]
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d DPI')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) controller.setDpi(v);
                  },
                ),
                const SizedBox(height: 16),

                _FieldLabel('Label Size'),
                DropdownButtonFormField<String>(
                  initialValue: state.labelSizeId,
                  items: LabelSize.catalog
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) controller.setLabelSize(v);
                  },
                ),
                const SizedBox(height: 20),

                if (state.testPrintMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      state.testPrintMessage!,
                      style: TextStyle(
                        color: state.testPrintMessage!.contains('success')
                            ? AppTheme.success
                            : AppTheme.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state.connectState == DeviceConnectState.connected &&
                                !state.isTestPrinting
                            ? controller.testPrint
                            : null,
                        icon: state.isTestPrinting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Test Print'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.canSave && !state.isSaving ? controller.save : null,
                    child: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }
}
