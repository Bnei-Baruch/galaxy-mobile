import 'dart:collection';

import 'package:flag/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_slider/flutter_volume_slider.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';

typedef BooleanCallback = void Function(bool isTrue);

class PlayerWidget extends StatefulWidget {
  bool isPlaying = false;
  BooleanCallback play;

  Map<String, Object> audioTypeValue;
  Map<String, Object> videoTypeValue;
  @override
  _PlayerStateWidget createState() => _PlayerStateWidget();
}

class _PlayerStateWidget extends State<PlayerWidget> {
  @override
  void InitState() {
    widget.isPlaying = false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 40),
            child: Row(
              children: [
                DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                FlatButton(
                  onPressed: () => widget.play(widget.isPlaying),
                  child: Icon(
                    widget.isPlaying ? Icons.stop : Icons.play_arrow,
                    color: Colors.grey,
                    size: 24.0,
                    semanticLabel: 'Play/Stop button',
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white),
                  child: Container(
                    // constraints:
                    //     BoxConstraints.tightForFinite(width: 150, height: 30),
                    height: 32,
                    width: 250,
                    child: FlutterVolumeSlider(
                      display: Display.HORIZONTAL,
                      sliderActiveColor: Colors.blue,
                      sliderInActiveColor: Colors.grey,
                    ),
                  ),
                ),
                FlatButton(
                  onPressed: null,
                  child: Icon(
                    Icons.fullscreen,
                    color: Colors.grey,
                    size: 24.0,
                    semanticLabel: 'Full screen',
                  ),
                ),
                FlatButton(
                  onPressed: null,
                  child: Icon(
                    Icons.settings,
                    color: Colors.grey,
                    size: 24.0,
                    semanticLabel: 'Full screen',
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              DropdownButton<Map<String, Object>>(
                  value: widget.videoTypeValue,
                  icon: Icon(Icons.arrow_downward),
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
                  icon: Icon(Icons.arrow_downward),
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
