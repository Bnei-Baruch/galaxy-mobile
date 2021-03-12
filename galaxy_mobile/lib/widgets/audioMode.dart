import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:provider/provider.dart';


class AudioMode extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    final audioMode = context.select((MainStore s) => s.audioMode);

    return SwitchListTile(
      title: const Text('Audio mode'),
      value: audioMode,
      secondary: const Icon(Icons.videocam_off),
      onChanged: (bool value) => {
        context.read<MainStore>().setAudioMode(value)
      },
    );
  }
}
