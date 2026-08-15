import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/printer/label_printer.dart';
import '../../../../core/printer/printer_session_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/app_sidebar.dart';
import '../../../printer_workspace/presentation/app_section_controller.dart';
import '../../../template_selection/presentation/template_selection_screen.dart';
import '../../domain/label_data.dart';
import '../../domain/label_template.dart';
import '../label_print_controller.dart';

class PrintDetailsPanel extends ConsumerWidget {
  const PrintDetailsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(printerSessionProvider);
    final state = ref.watch(labelPrintControllerProvider);
    final controller = ref.read(labelPrintControllerProvider.notifier);

    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Print Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),

          const _SectionLabel('TEMPLATE'),
          Row(
            children: [
              Expanded(
                child: Text(
                  state.fullTemplate.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _changeTemplate(context),
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const _SectionLabel('PRINTER'),
          Row(
            children: [
              const Icon(Icons.print_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.config?.name ?? 'No printer configured',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(status: session.status),
              IconButton(
                onPressed: () =>
                    ref.read(appSectionProvider.notifier).state = AppSection.settings,
                icon: const Icon(Icons.edit_outlined, size: 16),
                tooltip: session.config == null ? 'Set up printer' : 'Edit printer settings',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          if (session.status != PrinterConnectionStatus.connected)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton(
                onPressed: session.config == null
                    ? null
                    : () => ref.read(printerSessionProvider.notifier).reconnect(),
                child: const Text('Reconnect'),
              ),
            ),
          const SizedBox(height: 18),

          const _SectionLabel('LABEL SIZE'),
          Text(session.config?.labelSize.displayName ?? '3 × 2"'),
          const SizedBox(height: 18),

          if (state.labelData is PokeBowlLabelData) ...[
            const _SectionLabel('TOTAL AMOUNT'),
            TextFormField(
              key: ValueKey('amount-${state.formGeneration}'),
              initialValue: state.amountText,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Enter Amount', prefixText: '\$ '),
              onChanged: controller.updateAmount,
            ),
            const SizedBox(height: 18),
          ],

          const _SectionLabel('QUANTITY'),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: state.quantity > 1
                    ? () => controller.updateQuantity(state.quantity - 1)
                    : null,
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text('${state.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: () => controller.updateQuantity(state.quantity + 1),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (state.labelData.useBy case final useBy?) ...[
            _SectionLabel(
              state.template == LabelTemplateType.foodRotation
                  ? 'USE BY — FROM PREP'
                  : 'USE BY — FROM PACKED',
            ),
            TextFormField(
              key: ValueKey('usebyamount-${state.formGeneration}'),
              initialValue: state.useByAmount.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 12',
                suffixText: '1–24 = hours, 25+ = days',
                suffixStyle: TextStyle(fontSize: 11, color: Colors.black45),
              ),
              onChanged: (text) {
                final parsed = int.tryParse(text);
                if (parsed != null) controller.updateUseByAmount(parsed);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Use By: ${dateFormat.format(useBy)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 18),
          ],

          if (state.labelData case final PokeBowlLabelData pokeBowl) ...[
            const _SectionLabel('BARCODE'),
            Row(
              children: [
                const Expanded(
                  child: Text('Show Barcode', style: TextStyle(fontSize: 13)),
                ),
                Switch(
                  value: pokeBowl.showBarcode,
                  onChanged: controller.toggleShowBarcode,
                ),
              ],
            ),
            if (pokeBowl.showBarcode) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 16, color: Colors.black45),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Barcode: ${pokeBowl.barcodeDisplay}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  '(enter total to encode price)',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ),
            ],
            const SizedBox(height: 22),
          ],

          if (state.isPrinting)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  // The printer produces all copies from a single
                  // transmitted image via its own copy count, so progress
                  // here is indeterminate rather than per-copy.
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  Text(
                    'Sending ${state.printTotal} label'
                    '${state.printTotal == 1 ? '' : 's'} to printer...',
                  ),
                ],
              ),
            ),

          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: AppTheme.danger, fontSize: 13),
              ),
            ),
          if (state.resultMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                state.resultMessage!,
                style: const TextStyle(color: AppTheme.success, fontSize: 13),
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isPrinting ? null : controller.print,
              child: Text(state.isPrinting ? 'Printing...' : 'Print'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: state.isPrinting ? null : controller.reset,
              child: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns to Template Selection, clearing Food Selection/print-page
  /// history so re-picking a template always starts from a clean stack —
  /// [LabelPrintController.startNewLabel] (run when a template is next
  /// confirmed) already guarantees no field values leak between templates.
  void _changeTemplate(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TemplateSelectionScreen()),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.black45,
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: AppTheme.border)),
        child: Icon(icon, size: 16, color: onTap == null ? Colors.black26 : Colors.black87),
      ),
    );
  }
}
