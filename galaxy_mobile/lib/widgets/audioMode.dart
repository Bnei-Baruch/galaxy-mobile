import 'package:flutter/material.dart';

class AudioMode extends StatefulWidget {
  AudioMode();

  @override
  State createState() => _AudioModeState();
}

class _AudioModeState extends State<AudioMode> {
  bool useAudioMode = false;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Audio mode'),
      value: useAudioMode,
      onChanged: (bool value) {
        setState(() {
          useAudioMode = value;
        });
      },
    );
  }
}
