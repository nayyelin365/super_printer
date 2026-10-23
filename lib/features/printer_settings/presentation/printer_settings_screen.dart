import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/printer/models/connection_type.dart';
import '../../../core/printer/models/label_size.dart';
import '../../../core/printer/models/printer_config.dart';
import '../../../core/printer/printer_session_controller.dart';
import '../../../core/printer/saved_printers_controller.dart';
import '../../../shared/theme/app_theme.dart';
import 'printer_settings_controller.dart';
import 'widgets/discovered_device_tile.dart';

/// Routed at `/settings` — reached via the sidebar's Settings icon, or the
/// "Edit printer settings" shortcut on the print page.
class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printerSetupControllerProvider);
    final controller = ref.read(printerSetupControllerProvider.notifier);

    // Returns to wherever this screen was opened from — pops if it was
    // pushed (the print page's inline shortcut), or jumps to the print
    // page directly if it was reached as a top-level destination (the
    // sidebar), where there's nothing to pop back to.
    void goBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/print');
      }
    }

    ref.listen(printerSetupControllerProvider, (previous, next) {
      if (next.saved && previous?.saved != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer configuration saved.')),
        );
        if (next.connectState == DeviceConnectState.connected) {
          goBack();
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  if (context.canPop())
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                  Text(
                    'Printer Settings',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SavedPrintersList(),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        state.isEditingExisting ? 'Edit Printer' : 'New Printer',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),

                      const _FieldLabel('Name'),
                      TextFormField(
                        initialValue: state.name,
                        decoration: const InputDecoration(hintText: 'Name'),
                        onChanged: controller.setName,
                      ),
                      const SizedBox(height: 16),

                      const _FieldLabel('Printer Connection Type'),
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

                      const _FieldLabel('Printer Model'),
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

                      const _FieldLabel('Printer'),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
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

                      const _FieldLabel('DPI'),
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

                      const _FieldLabel('Label Size'),
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
                              onPressed:
                                  state.connectState == DeviceConnectState.connected &&
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every saved printer (across every label size), with Edit/Delete per
/// row and an "Add New Printer" action — the entry point for actually
/// having more than one saved printer, which nothing before this existed
/// to support (saving always just overwrote the single active one).
class _SavedPrintersList extends ConsumerWidget {
  const _SavedPrintersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printers = ref.watch(savedPrintersProvider);
    final activeId = ref.watch(printerSessionProvider).config?.id;
    final controller = ref.read(printerSetupControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'SAVED PRINTERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.black45,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => controller.editExisting(null),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add New Printer'),
            ),
          ],
        ),
        if (printers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No printers saved yet.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          )
        else
          for (final printer in printers)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _SavedPrinterTile(
                printer: printer,
                isActive: printer.id == activeId,
                onEdit: () => controller.editExisting(printer),
                onDelete: () => _confirmDelete(context, ref, printer),
              ),
            ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, PrinterConfig printer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Printer?'),
          content: Text('Are you sure you want to delete "${printer.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    await ref.read(printerSessionProvider.notifier).removeIfActive(printer.id);
    await ref.read(savedPrintersProvider.notifier).delete(printer.id);
  }
}

class _SavedPrinterTile extends StatelessWidget {
  const _SavedPrinterTile({
    required this.printer,
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
  });

  final PrinterConfig printer;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: isActive ? AppTheme.amber : AppTheme.border, width: isActive ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.print_outlined, size: 18, color: Colors.black45),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        printer.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '• Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${printer.labelSize.displayName} · ${printer.dpi} DPI · ${printer.connectionType.label}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
          ),
        ],
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
