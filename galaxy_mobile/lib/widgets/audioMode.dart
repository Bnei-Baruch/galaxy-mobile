import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class AudioMode extends StatelessWidget {
  final bool enabled = false;
  @override
  Widget build(BuildContext context) {
    final audioMode = context.select((MainStore s) => s.audioMode);

    return SwitchListTile(
      title: Text('audio_mode'.tr()),
      value: audioMode,
      secondary: const Icon(Icons.videocam_off),
      onChanged: (bool value) =>
          {context.read<MainStore>().setAudioMode(value)},
    );
  }

  bool isEnabled() {
    return enabled;
  }
}
