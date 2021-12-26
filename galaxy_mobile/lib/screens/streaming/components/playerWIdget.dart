import 'package:flag/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_slider/flutter_volume_slider.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';

typedef BooleanCallback = void Function(bool isTrue);

class PlayerWidget extends StatefulWidget {
  bool isPlaying = false;
  BooleanCallback play;
  BooleanCallback mute;
  BooleanCallback fullScreen;
  VoidCallback audioChange;
  VoidCallback videoChange;

  Map<String, Object> audioTypeValue;
  Map<String, Object> videoTypeValue;

  bool isMuted = false;
  bool isFullScreen = false;

  int audioPreset;

  int videoPreset;

  BuildContext dialogue;

  setStreamPresets(int audio, int video) {
    videoTypeValue = StreamConstants.videos_options
        .firstWhere((element) => element["value"] == video);
    audioTypeValue = StreamConstants.audiog_options
        .firstWhere((element) => element["value"] == audio);
  }

  toggleFullScreen() {
    isFullScreen = !isFullScreen;
    fullScreen(isFullScreen);
  }

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
      color: Colors.black12,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Container(
              //   width: 35.0,
              //   height: 35.0,
              //   child: DecoratedBox(
              //       child:

              IconButton(
                onPressed: () {
                  setState(() {
                    widget.isPlaying = !widget.isPlaying;
                    widget.play(widget.isPlaying);
                  });
                },
                icon: Icon(
                  widget.isPlaying ? Icons.stop : Icons.play_arrow,
                  color: Colors.white,
                  // size: 24.0,
                  semanticLabel: 'Play/Stop button',
                ),
              ),

              IconButton(
                onPressed: () {
                  setState(() {
                    widget.isMuted = !widget.isMuted;
                    widget.mute(widget.isMuted);
                  });
                },
                icon: Icon(
                  widget.isMuted ? Icons.volume_mute : Icons.volume_up,
                  color: Colors.white,
                  // size: 24.0,
                  semanticLabel: 'Play/Stop button',
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    showDialog(
                        useRootNavigator: false,
                        context: context,
                        builder: (context) {
                          widget.dialogue = context;
                          return Dialog(
                              insetPadding: EdgeInsets.only(
                                  right: MediaQuery
                                      .of(context)
                                      .size
                                      .width / 3),
                              child: Container(
                                  color: Colors.black12,
                                  width: 200,
                                  height: 150,
                                  child: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                        children: [
                                          Text("Language"),
                                          DropdownButton<Map<String, Object>>(
                                              value: widget.audioTypeValue,
                                              icon: Icon(
                                                  Icons.multitrack_audio),
                                              iconSize: 24,
                                              elevation: 16,
                                              style:
                                              TextStyle(color: Colors.white),
                                              underline: Container(
                                                height: 2,
                                                color: Colors.white,
                                              ),
                                              onChanged:
                                                  (Map<String,
                                                  Object> newValue) {
                                                setState(() {
                                                  widget.audioTypeValue =
                                                      newValue;
                                                  widget.audioChange();
                                                  Navigator.pop(widget.dialogue);
                                                  widget.dialogue = null;
                                                });
                                              },
                                              items: StreamConstants
                                                  .audiog_options
                                                  .map<
                                                  DropdownMenuItem<
                                                      Map<String,
                                                          Object>>>(
                                                      (Map<String, Object>
                                                  value) {
                                                    return DropdownMenuItem<
                                                        Map<String, Object>>(
                                                      value: value,
                                                      child: //Text(value["text"]),
                                                      Row(
                                                        children: <Widget>[
                                                          value.keys.contains(
                                                              "flag")
                                                              ? Flag(
                                                              value["flag"],
                                                              height: 24,
                                                              width: 24,
                                                              fit: BoxFit
                                                                  .contain)
                                                              : Icon(
                                                              Icons.group),
                                                          SizedBox(
                                                            width: 10,
                                                          ),
                                                          Text(
                                                            value["text"],
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList()),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                        children: [
                                          Text("Quality"),
                                          DropdownButton<Map<String, Object>>(
                                              value: widget.videoTypeValue,
                                              icon: Icon(Icons.video_label),
                                              iconSize: 24,
                                              elevation: 16,
                                              style:
                                              TextStyle(color: Colors.white),
                                              underline: Container(
                                                height: 2,
                                                color: Colors.white,
                                              ),
                                              onChanged:
                                                  (Map<String,
                                                  Object> newValue) {
                                                setState(() {
                                                  widget.videoTypeValue =
                                                      newValue;
                                                  widget.videoChange();
                                                  Navigator.pop(widget.dialogue);
                                                  widget.dialogue = null;
                                                });
                                              },
                                              items: StreamConstants
                                                  .videos_options
                                                  .map<
                                                  DropdownMenuItem<
                                                      Map<String,
                                                          Object>>>(
                                                      (Map<String, Object>
                                                  value) {
                                                    return DropdownMenuItem<
                                                        Map<String, Object>>(
                                                      value: value,
                                                      child: Text(
                                                          value["text"]),
                                                    );
                                                  }).toList()),
                                        ],
                                      )
                                    ],
                                  )));});
                  });
                },
                icon: Icon(
                  Icons.settings,
                  color: Colors.white,
                  // size: 24.0,
                  semanticLabel: 'Fullscreen button',
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    widget.toggleFullScreen();
                  });
                },
                icon: Icon(
                  widget.isFullScreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  color: Colors.white,
                  // size: 24.0,
                  semanticLabel: 'Fullscreen button',
                ),
              ),
            ],
          ),

          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceAround,
          //   children: [

          //
          //   ],
          // )
        ],
      ),
    );
  }
}
