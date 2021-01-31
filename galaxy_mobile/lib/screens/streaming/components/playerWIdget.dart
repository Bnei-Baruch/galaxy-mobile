import 'dart:collection';

import 'package:flag/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_slider/flutter_volume_slider.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';

typedef BooleanCallback = void Function(bool isTrue);

class PlayerWidget extends StatefulWidget {
  bool isPlaying = false;
  BooleanCallback play;
  VoidCallback audioChange;
  VoidCallback videoChange;

  Map<String, Object> audioTypeValue;
  Map<String, Object> videoTypeValue;
  @override
  _PlayerStateWidget createState() => _PlayerStateWidget();
}

class _PlayerStateWidget extends State<PlayerWidget> {
  @override
  void InitState() {
    widget.isPlaying = false;
    // Map<String, Object> audioTypeValue = StreamConstants.audiog_options
    //     .firstWhere((element) => element.keys.first == "he");
    // Map<String, Object> videoTypeValue = StreamConstants.videos_options
    //     .firstWhere((element) => element.keys.first == "1");
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 40),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Container(
                width: 35.0,
                height: 35.0,
                child: DecoratedBox(
                    child: IconButton(
                      // color: Colors.green,
                      onPressed: () => widget.play(widget.isPlaying),
                      icon: Icon(
                        widget.isPlaying ? Icons.stop : Icons.play_arrow,
                        color: Colors.black,
                        // size: 24.0,
                        semanticLabel: 'Play/Stop button',
                      ),
                    ),
                    decoration: BoxDecoration(color: Colors.white)),
              ),
              DecoratedBox(
                decoration: BoxDecoration(color: Colors.white),
                child: Container(
                  // constraints: BoxConstraints(minWidth: 100, maxWidth: 175),
                  height: 35,
                  width: 180,
                  child: FittedBox(
                    child: FlutterVolumeSlider(
                      display: Display.HORIZONTAL,
                      sliderActiveColor: Colors.blue,
                      sliderInActiveColor: Colors.grey,
                    ),
                  ),
                ),
              ),
              Container(
                width: 35.0,
                height: 35.0,
                child: DecoratedBox(
                    child: IconButton(
                      color: Colors.white,
                      // minWidth: 24,
                      onPressed: () => widget.play(widget.isPlaying),
                      icon: Icon(
                        Icons.fullscreen,
                        color: Colors.black,
                        // size: 24.0,
                        semanticLabel: 'Full screen',
                      ),
                    ),
                    decoration: BoxDecoration(color: Colors.white)),
              ),
              Container(
                width: 35.0,
                height: 35.0,
                child: DecoratedBox(
                    child: IconButton(
                      color: Colors.white,
                      // minWidth: 24,
                      onPressed: () => widget.play(widget.isPlaying),
                      icon: Icon(
                        Icons.settings,
                        color: Colors.black,
                        size: 24.0,
                        semanticLabel: 'Settings',
                      ),
                    ),
                    decoration: BoxDecoration(color: Colors.white)),
              ),
            ],
          ),
          Padding(padding: EdgeInsets.only(top: 35)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              DropdownButton<Map<String, Object>>(
                  value: widget.videoTypeValue,
                  icon: Icon(Icons.video_label),
                  iconSize: 24,
                  elevation: 16,
                  style: TextStyle(color: Colors.white),
                  underline: Container(
                    height: 2,
                    color: Colors.white,
                  ),
                  onChanged: (Map<String, Object> newValue) {
                    setState(() {
                      widget.videoTypeValue = newValue;
                      widget.videoChange();
                    });
                  },
                  items: StreamConstants.videos_options
                      .map<DropdownMenuItem<Map<String, Object>>>(
                          (Map<String, Object> value) {
                    return DropdownMenuItem<Map<String, Object>>(
                      value: value,
                      child: Text(value["text"]),
                    );
                  }).toList()),
              DropdownButton<Map<String, Object>>(
                  value: widget.audioTypeValue,
                  icon: Icon(Icons.multitrack_audio),
                  iconSize: 24,
                  elevation: 16,
                  style: TextStyle(color: Colors.white),
                  underline: Container(
                    height: 2,
                    color: Colors.white,
                  ),
                  onChanged: (Map<String, Object> newValue) {
                    setState(() {
                      widget.audioTypeValue = newValue;
                      widget.audioChange();
                    });
                  },
                  items: StreamConstants.audiog_options
                      .map<DropdownMenuItem<Map<String, Object>>>(
                          (Map<String, Object> value) {
                    return DropdownMenuItem<Map<String, Object>>(
                      value: value,
                      child: //Text(value["text"]),
                          Row(
                        children: <Widget>[
                          value.keys.contains("flag")
                              ? Flag(value["flag"],
                                  height: 24, width: 24, fit: BoxFit.contain)
                              : Icon(Icons.group),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            value["text"],
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  }).toList()),
            ],
          )
        ],
      ),
    );
  }
}
