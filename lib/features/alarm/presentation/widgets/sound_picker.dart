import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/alarm_sound.dart';

/// Lets the seller pick which [AlarmSound] plays when an alarm fires, with
/// a play/stop preview button per option (the "Default" system sound has
/// no preview — there's no bundled asset to play it from).
class SoundPicker extends StatefulWidget {
  const SoundPicker({super.key, required this.selectedId, required this.onChanged});

  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  State<SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends State<SoundPicker> {
  final _player = AudioPlayer();
  String? _previewingId;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewingId = null);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(AlarmSound sound) async {
    if (_previewingId == sound.id) {
      await _player.stop();
      setState(() => _previewingId = null);
      return;
    }
    final assetPath = sound.assetPath;
    if (assetPath == null) return;

    await _player.stop();
    setState(() => _previewingId = sound.id);
    await _player.play(AssetSource(assetPath.replaceFirst('assets/', '')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final sound in alarmSounds)
          RadioListTile<String>(
            value: sound.id,
            groupValue: widget.selectedId,
            onChanged: (value) => widget.onChanged(value!),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(sound.label, style: const TextStyle(fontSize: 14)),
            secondary: sound.assetPath == null
                ? null
                : IconButton(
                    onPressed: () => _togglePreview(sound),
                    icon: Icon(
                      _previewingId == sound.id ? Icons.stop_circle : Icons.play_circle_outline,
                      color: AppTheme.navyDark,
                    ),
                    tooltip: _previewingId == sound.id ? 'Stop preview' : 'Preview',
                  ),
          ),
      ],
    );
  }
}
