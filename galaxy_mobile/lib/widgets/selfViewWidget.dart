import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/Plugin.dart';

import 'dart:async';

class SelfViewWidget extends StatefulWidget {
  @override
  _SelfViewWidgetState createState() => _SelfViewWidgetState();
}

class _SelfViewWidgetState extends State<SelfViewWidget> {
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  Plugin pluginHandle;
  Plugin subscriberHandle;
  MediaStream myStream;

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    initRenderers();
  }

  initRenderers() {
    var mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth":
              '1280', // Provide your own width, height and frame rate here
          "minHeight": '720',
          "minFrameRate": '60',
        },
        "facingMode": "user",
        "optional": [],
      }
    };
    Future<MediaStream> stream = navigator.getUserMedia(mediaConstraints);

    stream.then((value) => setState(() {
          _localRenderer.srcObject = value;
        }));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: RTCVideoView(
        _localRenderer,
      ),
      height: 200,
      width: 200,
    );
  }
}
