import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/log_type.dart';
import 'widgets/log_type_card.dart';

/// The "Log Sheet" tab of [LogHomeScreen] — the four log-type cards; tapping
/// one opens its history screen at `/logs/<logType.id>`. Just the grid, since
/// the title/tabs above it already come from [LogHomeScreen].
class LogTypeListScreen extends StatelessWidget {
  const LogTypeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: LogType.values.length,
      itemBuilder: (context, index) {
        final logType = LogType.values[index];
        return LogTypeCard(
          logType: logType,
          onTap: () => context.push('/logs/${logType.id}'),
        );
      },
    );
  }
}
