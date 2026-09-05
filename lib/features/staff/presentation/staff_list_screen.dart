import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../data/staff_label_printer.dart';
import '../domain/staff_member.dart';
import 'staff_controller.dart';

/// Routed at `/employees` — full CRUD for the staff roster (name, role,
/// phone, email), on top of the same `employees` collection the Sushi Rice
/// SOP's quick "type a name" picker already uses. "Save & Print QR" prints
/// a 3x2 Staff ID badge whose QR code encodes the employee's Firestore doc
/// id — see `staff_label_printer.dart`.
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffMembersProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/templates'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text('Employees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openStaffForm(context, existing: null),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Employee'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: SizedBox(
                width: 280,
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    hintText: 'Search Name',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: staffAsync.when(
                data: (staff) {
                  final query = _search.trim().toLowerCase();
                  final filtered = query.isEmpty
                      ? staff
                      : staff.where((s) => s.name.toLowerCase().contains(query)).toList();

                  if (staff.isEmpty) {
                    return const Center(
                      child: Text(
                        'No employees yet. Tap "+ Add Employee" to add one.',
                        style: TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    );
                  }
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No employee matches "$_search".',
                        style: const TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: _StaffTable(staff: filtered, onEdit: (m) => _openStaffForm(context, existing: m)),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text('Could not load employees.\n$error', textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStaffForm(BuildContext context, {required StaffMember? existing}) async {
    final saved = await showDialog<StaffMember>(
      context: context,
      builder: (dialogContext) => _StaffFormDialog(existing: existing),
    );
    if (saved != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _StaffQrPrintDialog(member: saved),
      );
    }
  }
}

class _StaffTable extends StatelessWidget {
  const _StaffTable({required this.staff, required this.onEdit});

  final List<StaffMember> staff;
  final ValueChanged<StaffMember> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: _HeaderRow(),
          ),
          const Divider(height: 1),
          for (var i = 0; i < staff.length; i++) ...[
            _StaffRow(index: i + 1, member: staff[i], onEdit: () => onEdit(staff[i])),
            if (i != staff.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  static const _style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45);

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 32, child: Text('No', style: _style)),
        Expanded(flex: 2, child: Text('Name', style: _style)),
        Expanded(flex: 2, child: Text('Role', style: _style)),
        Expanded(flex: 2, child: Text('Phone Number', style: _style)),
        Expanded(flex: 3, child: Text('Email', style: _style)),
        Expanded(flex: 2, child: Text('Created Date', style: _style)),
        SizedBox(width: 90, child: Text('Actions', style: _style)),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.index, required this.member, required this.onEdit});

  final int index;
  final StaffMember member;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              member.role.isEmpty ? '-' : member.role,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(member.phoneNumber ?? '-', style: const TextStyle(fontSize: 13)),
          ),
          Expanded(flex: 3, child: Text(member.email ?? '-', style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 2,
            child: Text(
              member.createdAt == null ? '-' : DateFormat('d MMM yyyy').format(member.createdAt!),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          SizedBox(
            width: 90,
            child: Row(
              children: [
                _RowIconButton(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF1971C2),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                const SizedBox(width: 6),
                _RowIconButton(
                  icon: Icons.qr_code_2,
                  color: AppTheme.amber,
                  tooltip: 'View / Print QR',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => _StaffQrPrintDialog(member: member),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowIconButton extends StatelessWidget {
  const _RowIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// Add/Edit form. Returns the saved [StaffMember] on success (so the
/// caller can chain into the QR print dialog for a brand new employee),
/// null on cancel.
class _StaffFormDialog extends ConsumerStatefulWidget {
  const _StaffFormDialog({required this.existing});

  final StaffMember? existing;

  @override
  ConsumerState<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<_StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  String? _role;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _role = existing != null && existing.role.isNotEmpty ? existing.role : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(_isEditing ? 'Edit Employee' : 'New Employee', style: const TextStyle(fontSize: 18)),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Full Name', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Enter'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              const Text('Role', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Select'),
                items: [
                  for (final role in kitchenStaffRoles)
                    DropdownMenuItem(value: role, child: Text(role)),
                ],
                onChanged: (value) => setState(() => _role = value),
                validator: (v) => v == null ? 'Select a role' : null,
              ),
              const SizedBox(height: 16),
              const Text('Phone Number', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(hintText: 'Enter'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              const Text('Email Address', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'Enter'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.navyDark,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'SAVING...' : (_isEditing ? 'SAVE' : 'SAVE & PRINT QR')),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!await hasNetworkConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final controller = ref.read(staffControllerProvider);
      final name = _nameController.text.trim();
      final role = _role!;
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();

      final StaffMember saved;
      final existing = widget.existing;
      if (existing == null) {
        saved = await controller.create(
          name: name,
          role: role,
          phoneNumber: phone.isEmpty ? null : phone,
          email: email.isEmpty ? null : email,
        );
      } else {
        final updated = existing.copyWith(
          name: name,
          role: role,
          phoneNumber: phone.isEmpty ? null : phone,
          email: email.isEmpty ? null : email,
        );
        await controller.update(updated);
        saved = updated;
      }

      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Shows the employee's QR (encoding their Firestore doc id) and prints it
/// as a 3x2 Staff ID badge on demand — reachable right after creating an
/// employee, or any time later from a roster row's QR icon.
class _StaffQrPrintDialog extends ConsumerStatefulWidget {
  const _StaffQrPrintDialog({required this.member});

  final StaffMember member;

  @override
  ConsumerState<_StaffQrPrintDialog> createState() => _StaffQrPrintDialogState();
}

class _StaffQrPrintDialogState extends ConsumerState<_StaffQrPrintDialog> {
  bool _printing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final qrSvg = bc.Barcode.qrCode(
      errorCorrectLevel: bc.BarcodeQRCorrectionLevel.medium,
    ).toSvg(member.id, width: 220, height: 220, drawText: false);

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Staff Id QR Print', style: TextStyle(fontSize: 18))),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              member.role.isEmpty ? member.name : '${member.name} - ${member.role}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 20),
            SizedBox(width: 220, height: 220, child: SvgPicture.string(qrSvg)),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.danger),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/print');
                      },
                      child: const Text('Open Print Page to connect a printer'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navyDark,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _printing ? null : _print,
            child: Text(_printing ? 'PRINTING...' : 'PRINT'),
          ),
        ),
      ],
    );
  }

  Future<void> _print() async {
    setState(() {
      _printing = true;
      _error = null;
    });
    final result = await printStaffIdLabel(
      ref,
      employeeId: widget.member.id,
      name: widget.member.name,
      role: widget.member.role,
    );
    if (!mounted) return;
    setState(() {
      _printing = false;
      _error = result.success ? null : (result.errorMessage ?? 'Print failed.');
    });
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label sent to printer.')),
      );
    }
  }
}
