import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/printer/label_printer.dart';
import '../../../../core/printer/printer_session_controller.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/status_badge.dart';
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

          const _SectionLabel('TOTAL AMOUNT'),
          TextFormField(
            key: ValueKey('amount-${state.formGeneration}'),
            initialValue: state.amountText,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Enter Amount', prefixText: '\$ '),
            onChanged: controller.updateAmount,
          ),
          const SizedBox(height: 18),

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

          const _SectionLabel('USE BY — DAYS FROM PACKED'),
          Row(
            children: [2, 3, 4, 5]
                .map(
                  (d) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _UseByButton(
                        days: d,
                        selected: state.useByDays == d,
                        onTap: () => controller.updateUseByDays(d),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Use By: ${dateFormat.format(state.labelData.useBy)}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 18),

          const _SectionLabel('BARCODE'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: TextFormField(
              key: ValueKey('barcode-${state.formGeneration}'),
              initialValue: state.labelData.barcode,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Barcode value',
              ),
              onChanged: controller.updateBarcode,
            ),
          ),
          const SizedBox(height: 22),

          if (state.isPrinting)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: state.printTotal == 0
                        ? null
                        : state.printedCount / state.printTotal,
                  ),
                  const SizedBox(height: 6),
                  Text('Printing ${state.printedCount} / ${state.printTotal}'),
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

class _UseByButton extends StatelessWidget {
  const _UseByButton({required this.days, required this.selected, required this.onTap});
  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.navyDark : Colors.white,
          border: Border.all(color: selected ? AppTheme.navyDark : AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+${days}d',
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
