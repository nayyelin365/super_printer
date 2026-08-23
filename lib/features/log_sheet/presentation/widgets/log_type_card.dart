import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/log_type.dart';

class LogTypeCard extends StatelessWidget {
  const LogTypeCard({super.key, required this.logType, required this.onTap});

  final LogType logType;
  final VoidCallback onTap;

  IconData get _icon => switch (logType) {
    LogType.sushiRice => Icons.rice_bowl_outlined,
    LogType.temperature => Icons.thermostat_outlined,
    LogType.cooling => Icons.ac_unit,
    LogType.recooling => Icons.replay,
    LogType.coolPrep => Icons.kitchen_outlined,
    LogType.thawing => Icons.water_drop_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: AppTheme.navyDark),
              ),
              const SizedBox(height: 14),
              Text(
                logType.label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
