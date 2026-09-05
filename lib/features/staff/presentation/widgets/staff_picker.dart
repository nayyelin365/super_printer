import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../shared/theme/app_theme.dart';
import '../staff_controller.dart';

/// Identifies "who is doing this step" purely by scanning their Staff ID
/// QR badge (see `staff_label_printer.dart` — the QR encodes the
/// employee's Firestore doc id) rather than picking/typing a name. Once a
/// scanned code matches a known roster entry, calls [onChanged] with that
/// employee's id; [selectedId] set means "already identified", which shows
/// a confirmation row instead of the camera. Deliberately no manual
/// fallback: staff scan their own badge, they don't pick their name off a
/// list or type it.
class StaffNamePicker extends ConsumerStatefulWidget {
  const StaffNamePicker({super.key, required this.selectedId, required this.onChanged});

  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<StaffNamePicker> createState() => _StaffNamePickerState();
}

class _StaffNamePickerState extends ConsumerState<StaffNamePicker> {
  late final MobileScannerController _controller;
  String? _error;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffMembersProvider);
    final selected = widget.selectedId == null
        ? null
        : staffAsync.valueOrNull?.where((s) => s.id == widget.selectedId).firstOrNull;

    if (selected != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.success),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selected.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (selected.role.isNotEmpty)
                    Text(selected.role, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _error = null);
                widget.onChanged(null);
                _controller.start();
              },
              child: const Text('Scan Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan your staff QR',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MobileScanner(controller: _controller, onDetect: _handleDetect),
                    ),
                    const IgnorePointer(child: CustomPaint(painter: _ScanFramePainter())),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12), textAlign: TextAlign.center),
        ],
      ],
    );
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_handling) return;
    final rawValue = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (rawValue == null) return;

    final staff = ref.read(staffMembersProvider).valueOrNull ?? const [];
    final match = staff.where((s) => s.id == rawValue).firstOrNull;
    if (match == null) {
      setState(() => _error = 'Unrecognized QR code. Scan a valid Staff ID badge.');
      return;
    }

    _handling = true;
    _controller.stop();
    setState(() => _error = null);
    widget.onChanged(match.id);
  }
}

/// Simple corner-bracket viewfinder overlay, drawn on top of the live
/// camera preview.
class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const armLength = 20.0;
    const inset = 8.0;

    void corner(Offset origin, Offset dx, Offset dy) {
      canvas.drawLine(origin, origin + dx, paint);
      canvas.drawLine(origin, origin + dy, paint);
    }

    corner(
      const Offset(inset, inset),
      const Offset(armLength, 0),
      const Offset(0, armLength),
    );
    corner(
      Offset(size.width - inset, inset),
      const Offset(-armLength, 0),
      const Offset(0, armLength),
    );
    corner(
      Offset(inset, size.height - inset),
      const Offset(armLength, 0),
      const Offset(0, -armLength),
    );
    corner(
      Offset(size.width - inset, size.height - inset),
      const Offset(-armLength, 0),
      const Offset(0, -armLength),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
