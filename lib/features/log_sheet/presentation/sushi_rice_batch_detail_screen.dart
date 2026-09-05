import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/network_error.dart';
import '../../staff/presentation/staff_controller.dart';
import '../../staff/presentation/widgets/staff_picker.dart';
import '../domain/sushi_rice_batch.dart';
import 'sushi_rice_batch_controller.dart';

/// Shared sizing for this screen's full-width action buttons (Start
/// Cooking/Mixing, Measure pH, Save & Print, Acknowledge, Finish Batch,
/// Retry Print) — same 56px-tall, bold, rounded look the new-batch flow
/// uses, so a stage's main CTA isn't a cramped default-height button.
ButtonStyle _bigActionStyle([Color? backgroundColor]) => ElevatedButton.styleFrom(
  backgroundColor: backgroundColor,
  minimumSize: const Size.fromHeight(56),
  padding: const EdgeInsets.symmetric(vertical: 16),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

/// Shared sizing for this screen's dialog action buttons (Start Cooking,
/// Start Mixing, Continue, Finish Batch confirmations) — dialogs keep
/// Flutter's compact default height for Cancel/Back, but the primary
/// confirm button gets real padding instead of hugging its text.
ButtonStyle _dialogConfirmStyle([Color? backgroundColor]) => ElevatedButton.styleFrom(
  backgroundColor: backgroundColor,
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
);

ButtonStyle _bigOutlinedActionStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(56),
  padding: const EdgeInsets.symmetric(vertical: 16),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

/// Routed at `/logs/sushiRice/batch/:batchId`. Soaking, Cooking & Rest, and
/// Mixing & Cooling share the same shape (fixed countdown, a "start next
/// step" button locked until the SOP's minimum time, a red "Time's Up!"
/// state once the max is reached) — pH Check and Ready to Use aren't built
/// yet, so a batch that reaches them shows a clear placeholder instead of
/// a guessed-at flow.
class SushiRiceBatchDetailScreen extends ConsumerStatefulWidget {
  const SushiRiceBatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<SushiRiceBatchDetailScreen> createState() => _SushiRiceBatchDetailScreenState();
}

class _SushiRiceBatchDetailScreenState extends ConsumerState<SushiRiceBatchDetailScreen> {
  Timer? _tick;
  bool _busy = false;
  bool _autoExpireChecked = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      _maybeAutoExpire();
    });
  }

  /// Fires [SushiRiceBatchController.autoExpireIfNeeded] at most once per
  /// screen visit — the method itself is a no-op once the batch is
  /// finished, this flag just avoids spamming Firestore every second while
  /// waiting for that update to stream back.
  void _maybeAutoExpire() {
    if (_autoExpireChecked) return;
    final batch = ref.read(sushiRiceBatchProvider(widget.batchId)).value;
    if (batch == null || batch.stage != SushiRiceStage.readyToUse || batch.finishedAt != null) {
      return;
    }
    final deadline = batch.readyToUseDeadline;
    if (deadline == null || !DateTime.now().isAfter(deadline)) return;
    _autoExpireChecked = true;
    ref.read(sushiRiceBatchControllerProvider).autoExpireIfNeeded(batch);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchAsync = ref.watch(sushiRiceBatchProvider(widget.batchId));

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
                  Text(
                    batchAsync.value?.batchCode ?? widget.batchId,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: batchAsync.when(
                data: (batch) => Center(
                  child: batch == null
                      ? const Text('This batch no longer exists.')
                      : _buildBody(batch),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setBusy(bool value) => setState(() => _busy = value);

  Widget _buildBody(SushiRiceBatch batch) {
    switch (batch.stage) {
      case SushiRiceStage.soaking:
        return _SoakingView(batch: batch, busy: _busy, onBusy: _setBusy);
      case SushiRiceStage.cookingRest:
        return _CookingRestView(batch: batch, busy: _busy, onBusy: _setBusy);
      case SushiRiceStage.mixingCooling:
        return _MixingCoolingView(batch: batch, busy: _busy, onBusy: _setBusy);
      case SushiRiceStage.phCheck:
        return _PhCheckView(batch: batch, busy: _busy, onBusy: _setBusy);
      case SushiRiceStage.readyToUse:
        return _ReadyToUseView(batch: batch, busy: _busy, onBusy: _setBusy);
    }
  }
}

/// Shared card layout for every fixed-countdown stage: batch info on the
/// left, the countdown ring + upcoming-buzzer note + action button on the
/// right. Stage-specific behavior (what the button does, print retry for
/// Soaking) is handled by the caller.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stateLabel,
    required this.employeeName,
    required this.startedAt,
    required this.remaining,
    required this.totalMinutes,
    required this.ringColor,
    required this.upcomingBuzzerLabel,
    required this.actionLabel,
    required this.actionEnabled,
    required this.onAction,
    this.unlockHint,
    this.trailing,
  });

  final String stateLabel;
  final String employeeName;
  final DateTime startedAt;
  final Duration remaining;
  final int totalMinutes;
  final Color ringColor;
  final String upcomingBuzzerLabel;
  final String actionLabel;
  final bool actionEnabled;
  final VoidCallback onAction;
  final String? unlockHint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final timeIsUp = remaining <= Duration.zero;
    final color = timeIsUp ? AppTheme.danger : ringColor;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stateLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(stateLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.person_outline, label: 'EMPLOYEE', value: employeeName),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'STARTED AT',
                    value: DateFormat('h:mm a').format(startedAt),
                  ),
                  if (trailing != null) ...[const SizedBox(height: 16), trailing!],
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeIsUp ? "Time's Up!" : 'Time Remaining',
                    style: TextStyle(
                      color: color,
                      fontWeight: timeIsUp ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CountdownRing(remaining: remaining, totalMinutes: totalMinutes, color: color),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_outlined, size: 18, color: Color(0xFF1971C2)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Upcoming Buzzer Alert',
                                style: TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                              Text(
                                upcomingBuzzerLabel,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: _bigActionStyle(),
                      onPressed: actionEnabled ? onAction : null,
                      child: Text(actionLabel),
                    ),
                  ),
                  if (!actionEnabled && unlockHint != null) ...[
                    const SizedBox(height: 8),
                    Text(unlockHint!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoakingView extends ConsumerWidget {
  const _SoakingView({required this.batch, required this.busy, required this.onBusy});

  final SushiRiceBatch batch;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endsAt = batch.soakEndsAt;
    if (endsAt == null || batch.soakStartedAt == null) return const Text('Missing soak timer data.');

    final cookByDeadline = batch.soakCookByDeadline;
    if (cookByDeadline != null && DateTime.now().isAfter(cookByDeadline)) {
      return _CookingWindowExpiredCard(batch: batch, busy: busy, onBusy: onBusy);
    }

    final elapsed = DateTime.now().difference(batch.soakStartedAt!);
    final remaining = endsAt.difference(DateTime.now());
    final canAct = elapsed.inMinutes >= sushiRiceSoakUnlockMinutes;

    return _StageCard(
      stateLabel: 'State 1 - Soaking',
      employeeName: batch.staffName ?? '-',
      startedAt: batch.soakStartedAt!,
      remaining: remaining,
      totalMinutes: sushiRiceSoakTotalMinutes,
      ringColor: AppTheme.success,
      upcomingBuzzerLabel: 'Cooking & Rest',
      actionLabel: 'START COOKING',
      actionEnabled: canAct && !busy,
      unlockHint: 'Available in ${sushiRiceSoakUnlockMinutes - elapsed.inMinutes} min',
      onAction: () => _openNameOnlyDialog(
        context: context,
        ref: ref,
        title: batch.batchCode,
        confirmLabel: 'START COOKING',
        confirmColor: AppTheme.success,
        onConfirm: (staffId, staffName) async {
          await ref
              .read(sushiRiceBatchControllerProvider)
              .startCooking(batch, staffId: staffId, staffName: staffName);
        },
      ),
      trailing: !batch.labelPrinted
          ? _PrintFailedBanner(
              busy: busy,
              onRetry: () async {
                onBusy(true);
                try {
                  if (!await hasNetworkConnection()) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Network error. Please check your internet connection.'),
                        ),
                      );
                    }
                    return;
                  }
                  final result =
                      await ref.read(sushiRiceBatchControllerProvider).retryLabelPrint(batch);
                  if (!context.mounted) return;
                  if (!result.labelPrinted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.printError ?? 'Could not print the label.')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
                  }
                } finally {
                  onBusy(false);
                }
              },
            )
          : null,
    );
  }
}

/// Shown instead of the normal Soaking countdown once
/// [SushiRiceBatch.soakCookByDeadline] (the soaking method's food-safety
/// limit — 72 hr fridge / 2 hr room temp, not the 20–30 min buzzer) has
/// passed: cooking this batch is no longer safe, so the only action left
/// is Discard.
class _CookingWindowExpiredCard extends ConsumerWidget {
  const _CookingWindowExpiredCard({required this.batch, required this.busy, required this.onBusy});

  final SushiRiceBatch batch;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDEDED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.danger),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active, color: AppTheme.danger, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batch.batchCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(
                        'Soaking in ${(batch.soakingMethod ?? '').toLowerCase()}',
                        style: const TextStyle(color: Color(0xFF1971C2), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '00:00',
                  style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Cooking Window Expired',
              style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('The cooking window for Sushi Rice ${batch.batchCode} has expired. '
                'This batch must be discarded.'),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Time Remaining to Start Cooking -  ',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const TextSpan(
                    text: '00:00:00',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 200,
                child: ElevatedButton(
                  style: _bigActionStyle(AppTheme.danger),
                  onPressed: busy
                      ? null
                      : () => _openFinishDialog(
                          context: context,
                          ref: ref,
                          batch: batch,
                          onBusy: onBusy,
                          defaultStatus: 'Discarded',
                        ),
                  child: const Text('Discard Batch'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookingRestView extends ConsumerWidget {
  const _CookingRestView({required this.batch, required this.busy, required this.onBusy});

  final SushiRiceBatch batch;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endsAt = batch.cookRestEndsAt;
    if (endsAt == null || batch.cookRestStartedAt == null) {
      return const Text('Missing Cook & Rest timer data.');
    }

    final elapsed = DateTime.now().difference(batch.cookRestStartedAt!);
    final remaining = endsAt.difference(DateTime.now());
    final canAct = elapsed.inMinutes >= sushiRiceCookRestUnlockMinutes;

    return _StageCard(
      stateLabel: 'State 2 - Cooking & Rest',
      employeeName: batch.cookRestStaffName ?? '-',
      startedAt: batch.cookRestStartedAt!,
      remaining: remaining,
      totalMinutes: sushiRiceCookRestTotalMinutes,
      ringColor: AppTheme.danger,
      upcomingBuzzerLabel: 'Mix Seasoning Vinegar & Cooling',
      actionLabel: 'MIX SEASONING VINEGAR',
      actionEnabled: canAct && !busy,
      unlockHint: 'Available in ${sushiRiceCookRestUnlockMinutes - elapsed.inMinutes} min',
      onAction: () => _openVinegarDialog(context: context, ref: ref, batch: batch),
    );
  }

  Future<void> _openVinegarDialog({
    required BuildContext context,
    required WidgetRef ref,
    required SushiRiceBatch batch,
  }) async {
    double vinegarOz = sushiRiceVinegarAmountsOz.first;
    String? staffId;
    String? staffName;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(batch.batchCode),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science_outlined, size: 16, color: Colors.black54),
                        SizedBox(width: 6),
                        Text('Add Vinegar Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final oz in sushiRiceVinegarAmountsOz)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<double>(
                                value: oz,
                                groupValue: vinegarOz,
                                onChanged: (value) => setDialogState(() => vinegarOz = value!),
                              ),
                              Text('${oz.toStringAsFixed(0)} Oz'),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StaffNamePicker(
                      selectedId: staffId,
                      onChanged: (id) {
                        final staff = ref.read(staffMembersProvider).valueOrNull ?? const [];
                        setDialogState(() {
                          staffId = id;
                          staffName = staff.where((s) => s.id == id).firstOrNull?.name;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('← BACK'),
                ),
                ElevatedButton(
                  style: _dialogConfirmStyle(AppTheme.success),
                  onPressed: staffId == null ? null : () => Navigator.of(dialogContext).pop(true),
                  child: const Text('START MIXING'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || staffId == null || staffName == null) return;

    if (!await hasNetworkConnection()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      }
      return;
    }

    onBusy(true);
    try {
      await ref
          .read(sushiRiceBatchControllerProvider)
          .startMixing(batch, vinegarAmountOz: vinegarOz, staffId: staffId!, staffName: staffName!);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
      }
    } finally {
      onBusy(false);
    }
  }
}

class _MixingCoolingView extends ConsumerWidget {
  const _MixingCoolingView({required this.batch, required this.busy, required this.onBusy});

  final SushiRiceBatch batch;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endsAt = batch.mixCoolEndsAt;
    if (endsAt == null || batch.mixCoolStartedAt == null) {
      return const Text('Missing Mixing & Cooling timer data.');
    }

    final elapsed = DateTime.now().difference(batch.mixCoolStartedAt!);
    final remaining = endsAt.difference(DateTime.now());
    final canAct = elapsed.inMinutes >= sushiRiceMixCoolUnlockMinutes;

    return _StageCard(
      stateLabel: 'State 3 - Mixing Vinegar & Cooling',
      employeeName: batch.mixCoolStaffName ?? '-',
      startedAt: batch.mixCoolStartedAt!,
      remaining: remaining,
      totalMinutes: sushiRiceMixCoolTotalMinutes,
      ringColor: AppTheme.navyDark,
      upcomingBuzzerLabel: 'Measure pH Level',
      actionLabel: 'MEASURE PH LEVEL',
      actionEnabled: canAct && !busy,
      unlockHint: 'Available in ${sushiRiceMixCoolUnlockMinutes - elapsed.inMinutes} min',
      onAction: () => _openNameOnlyDialog(
        context: context,
        ref: ref,
        title: 'Choose Your Name',
        confirmLabel: 'CONTINUE →',
        confirmColor: null,
        onConfirm: (staffId, staffName) async {
          await ref
              .read(sushiRiceBatchControllerProvider)
              .startPhCheck(batch, staffId: staffId, staffName: staffName);
        },
      ),
    );
  }
}

/// Shared "pick/enter a name, then confirm" dialog used by Soaking's Start
/// Cooking and Mixing & Cooling's Measure pH Level — the only difference
/// between them is the title/button text/color, which the caller supplies.
Future<void> _openNameOnlyDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String confirmLabel,
  required Color? confirmColor,
  required Future<void> Function(String staffId, String staffName) onConfirm,
}) async {
  String? staffId;
  String? staffName;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 380,
              child: StaffNamePicker(
                selectedId: staffId,
                onChanged: (id) {
                  final staff = ref.read(staffMembersProvider).valueOrNull ?? const [];
                  setDialogState(() {
                    staffId = id;
                    staffName = staff.where((s) => s.id == id).firstOrNull?.name;
                  });
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('← BACK'),
              ),
              ElevatedButton(
                style: _dialogConfirmStyle(confirmColor),
                onPressed: staffId == null ? null : () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true || staffId == null || staffName == null) return;

  if (!await hasNetworkConnection()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please check your internet connection.')),
      );
    }
    return;
  }

  try {
    await onConfirm(staffId!, staffName!);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
    }
  }
}

class _PrintFailedBanner extends StatelessWidget {
  const _PrintFailedBanner({required this.busy, required this.onRetry});

  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The batch label failed to print.',
            style: TextStyle(color: AppTheme.danger, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: _bigOutlinedActionStyle(),
              onPressed: busy ? null : onRetry,
              child: Text(busy ? 'Retrying...' : 'Retry Print'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.remaining, required this.totalMinutes, required this.color});

  final Duration remaining;
  final int totalMinutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = remaining <= Duration.zero ? Duration.zero : remaining;
    final minutes = (clamped.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
    final progress = (clamped.inSeconds / (totalMinutes * 60)).clamp(0.0, 1.0);

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              color: color,
              backgroundColor: AppTheme.border,
            ),
          ),
          Text(
            '$minutes:$seconds',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _PhCheckView extends ConsumerStatefulWidget {
  const _PhCheckView({required this.batch, required this.busy, required this.onBusy});

  final SushiRiceBatch batch;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  ConsumerState<_PhCheckView> createState() => _PhCheckViewState();
}

class _PhCheckViewState extends ConsumerState<_PhCheckView> {
  double _reading = 0;
  bool _submittedOnce = false;
  bool _retesting = false;
  String? _printError;

  bool get _isFail => _submittedOnce && _reading > sushiRicePhPassThreshold;

  @override
  Widget build(BuildContext context) {
    if (_printError != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.print_disabled, color: AppTheme.danger, size: 48),
            const SizedBox(height: 16),
            Text(_printError!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              style: _bigActionStyle(),
              onPressed: widget.busy ? null : _retryPrint,
              child: Text(widget.busy ? 'Retrying...' : 'Retry Print'),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entry pH Level', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isFail ? AppTheme.danger.withValues(alpha: 0.06) : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _isFail ? AppTheme.danger : AppTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _reading.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: _submittedOnce
                                    ? (_isFail ? AppTheme.danger : AppTheme.success)
                                    : Colors.black26,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: Text('pH', style: TextStyle(color: Colors.black54)),
                            ),
                          ],
                        ),
                        Text(
                          _submittedOnce ? '' : 'Type pH value',
                          style: const TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _reading = (_reading + 0.1).clamp(0, 14)),
                        icon: const Icon(Icons.add, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () => setState(() => _reading = (_reading - 0.1).clamp(0, 14)),
                        icon: const Icon(Icons.remove, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_submittedOnce) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _isFail ? Icons.warning_amber : Icons.check_circle,
                    size: 14,
                    color: _isFail ? AppTheme.danger : AppTheme.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isFail
                          ? 'The pH level is outside the critical limit. Please take corrective '
                              'action and retest.'
                          : 'The pH level is within the acceptable limit.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isFail ? AppTheme.danger : AppTheme.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (_isFail && !_retesting)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: _bigActionStyle(),
                  onPressed: () => setState(() {
                    _retesting = true;
                    _submittedOnce = false;
                    _reading = 0;
                  }),
                  child: const Text('CORRECTION ACTION'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: _bigActionStyle(AppTheme.success),
                  onPressed: widget.busy ? null : _save,
                  child: Text(widget.busy ? 'Saving...' : 'SAVE & PRINT'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!await hasNetworkConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      }
      return;
    }

    widget.onBusy(true);
    try {
      final controller = ref.read(sushiRiceBatchControllerProvider);
      final outcome = _retesting
          ? await controller.recordCorrectiveRetest(widget.batch, _reading)
          : await controller.submitPhReading(widget.batch, _reading);
      if (!mounted) return;
      switch (outcome) {
        case PhOutcome.passedAndLabelPrinted:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('pH passed — 24-Hr label printed. Ready to Use.')),
          );
        case PhOutcome.passedButPrintFailed:
          setState(
            () => _printError = 'Printer is not connected. Fix the printer, then retry.',
          );
        case PhOutcome.failed:
          setState(() => _submittedOnce = true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
      }
    } finally {
      if (mounted) widget.onBusy(false);
    }
  }

  Future<void> _retryPrint() async {
    widget.onBusy(true);
    try {
      final outcome =
          await ref.read(sushiRiceBatchControllerProvider).retryTphcLabelPrint(widget.batch);
      if (!mounted) return;
      if (outcome == PhOutcome.passedAndLabelPrinted) {
        setState(() => _printError = null);
      } else {
        setState(() => _printError = 'Still could not print. Check the printer connection.');
      }
    } finally {
      if (mounted) widget.onBusy(false);
    }
  }
}

class _ReadyToUseView extends ConsumerWidget {
  const _ReadyToUseView({required this.batch, required this.busy, required this.onBusy});

  final SushiRiceBatch batch;
  final bool busy;
  final ValueChanged<bool> onBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadline = batch.readyToUseDeadline;
    final remaining = deadline?.difference(DateTime.now()) ?? Duration.zero;
    final expired = remaining <= Duration.zero;
    final hoursElapsed =
        batch.readyToUseStartedAt == null ? 0 : DateTime.now().difference(batch.readyToUseStartedAt!).inHours;
    final nextAlertHour = sushiRiceTphcAlertHours.firstWhere(
      (h) => h > (batch.lastAcknowledgedHour ?? 0) && h <= hoursElapsed,
      orElse: () => 0,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ready to Use',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: expired ? AppTheme.danger : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            expired
                ? 'Window expired — discard this batch.'
                : '${remaining.inHours}h ${remaining.inMinutes % 60}m remaining',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'pH ${batch.phReading?.toStringAsFixed(1) ?? '-'} — label printed for '
            '"${batch.foodName ?? 'this batch'}" at ${batch.readyToUseStartedAt}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          if (nextAlertHour > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.danger),
              ),
              child: Column(
                children: [
                  Text(
                    'Hour $nextAlertHour compliance check needed',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.danger),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: _bigActionStyle(AppTheme.danger),
                    onPressed: busy
                        ? null
                        : () async {
                            onBusy(true);
                            try {
                              await ref
                                  .read(sushiRiceBatchControllerProvider)
                                  .acknowledgeHour(batch, sushiRiceTphcAlertHours.indexOf(nextAlertHour));
                            } finally {
                              onBusy(false);
                            }
                          },
                    child: const Text('Acknowledge'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: _bigOutlinedActionStyle(),
                  onPressed: busy
                      ? null
                      : () => _openFinishDialog(
                          context: context,
                          ref: ref,
                          batch: batch,
                          onBusy: onBusy,
                          defaultStatus: 'Discarded',
                        ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: _bigActionStyle(AppTheme.navyDark),
                  onPressed: busy
                      ? null
                      : () => _openFinishDialog(
                          context: context,
                          ref: ref,
                          batch: batch,
                          onBusy: onBusy,
                          defaultStatus: 'Used',
                        ),
                  child: const Text('Finish Batch'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "Final Batch Status" dialog (status choice + who's recording it) —
/// shared by Ready to Use's Discard/Finish Batch buttons and Soaking's
/// "Cooking Window Expired" card, which only ever discards. [defaultStatus]
/// just pre-selects a chip; the dialog still lets the choice be changed.
Future<void> _openFinishDialog({
  required BuildContext context,
  required WidgetRef ref,
  required SushiRiceBatch batch,
  required ValueChanged<bool> onBusy,
  required String defaultStatus,
}) async {
  String? status = defaultStatus;
  String? staffId;
  String? staffName;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(batch.batchCode),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Final Batch Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in sushiRiceFinalStatuses)
                        ChoiceChip(
                          label: Text(option),
                          selected: status == option,
                          onSelected: (_) => setDialogState(() => status = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StaffNamePicker(
                    selectedId: staffId,
                    onChanged: (id) {
                      final staff = ref.read(staffMembersProvider).valueOrNull ?? const [];
                      setDialogState(() {
                        staffId = id;
                        staffName = staff.where((s) => s.id == id).firstOrNull?.name;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('← BACK'),
              ),
              ElevatedButton(
                style: _dialogConfirmStyle(),
                onPressed: staffId == null ? null : () => Navigator.of(dialogContext).pop(true),
                child: const Text('FINISH BATCH'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true || staffId == null || staffName == null || status == null) return;

  if (!await hasNetworkConnection()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please check your internet connection.')),
      );
    }
    return;
  }

  onBusy(true);
  try {
    await ref
        .read(sushiRiceBatchControllerProvider)
        .setFinalBatchStatus(batch, status: status!, staffId: staffId!, staffName: staffName!);
    if (context.mounted) context.pop();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(networkAwareErrorMessage(error))));
    }
  } finally {
    onBusy(false);
  }
}
