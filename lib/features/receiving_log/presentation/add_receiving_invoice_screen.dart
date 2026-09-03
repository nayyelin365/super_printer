import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../../staff/presentation/staff_controller.dart';
import '../../staff/presentation/widgets/staff_picker.dart';
import 'receiving_log_controller.dart';

/// Routed at `/receiving-log/new` — "Add Receiving Log": creates the parent
/// invoice, then moves straight to adding its first item (an invoice must
/// exist before items can be added to it).
class AddReceivingInvoiceScreen extends ConsumerStatefulWidget {
  const AddReceivingInvoiceScreen({super.key});

  @override
  ConsumerState<AddReceivingInvoiceScreen> createState() => _AddReceivingInvoiceScreenState();
}

class _AddReceivingInvoiceScreenState extends ConsumerState<AddReceivingInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  String _supplierName = '';
  String _invoiceNo = '';
  String? _staffId;
  String? _staffName;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const Expanded(
                    child: Text(
                      'Add Receiving Log',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    DateFormat('EEE MMM d, yyyy h:mma').format(now),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Supplier Name',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  decoration: const InputDecoration(hintText: 'Enter Supplier'),
                                  onChanged: (value) => _supplierName = value,
                                  validator: (value) => (value == null || value.trim().isEmpty)
                                      ? 'Enter a supplier name'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Invoice No.',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  decoration: const InputDecoration(hintText: 'Enter Invoice No.'),
                                  onChanged: (value) => _invoiceNo = value,
                                  validator: (value) => (value == null || value.trim().isEmpty)
                                      ? 'Enter an invoice number'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: StaffNamePicker(
                              selectedId: _staffId,
                              onChanged: (id) {
                                final staff = ref.read(staffMembersProvider).valueOrNull ?? const [];
                                setState(() {
                                  _staffId = id;
                                  _staffName = staff.where((s) => s.id == id).firstOrNull?.name;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _saving ? null : _save,
                              child: Text(
                                _saving ? 'Saving...' : 'Save & Add Receiving Item',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_staffId == null || _staffName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter or select who received this.')));
      return;
    }
    if (!await hasNetworkConnection()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please check your internet connection.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final invoice = await ref.read(receivingLogControllerProvider).createInvoice(
            invoiceNo: _invoiceNo.trim(),
            supplierName: _supplierName.trim(),
            receivedAt: DateTime.now(),
            staffId: _staffId!,
            staffName: _staffName!,
          );
      if (!mounted) return;
      context.pushReplacement('/receiving-log/invoice/${invoice.id}/new-item');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
