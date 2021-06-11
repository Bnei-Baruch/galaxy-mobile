import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/Plugin.dart';

import 'dart:async';

class SelfViewWidget extends StatefulWidget {
  @override
  _SelfViewWidgetState createState() => _SelfViewWidgetState();

  var state;
  restartCamera() {
    if (state != null && state.mounted) {
      state.initRenderers();
    }
  }
}

class _SelfViewWidgetState extends State<SelfViewWidget>
    with WidgetsBindingObserver {
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
    widget.state = this;
    print('xxx SelfViewWidget initstate');
    WidgetsBinding.instance.addObserver(this);
    _localRenderer.initialize();
    initRenderers();
  }

  @override
  void dispose() {
    _localRenderer.srcObject = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    Future<MediaStream> stream =
        navigator.mediaDevices.getUserMedia(mediaConstraints);

    stream.then((value) => setState(() {
          _localRenderer.srcObject = value;
        }));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: RTCVideoView(
        _localRenderer,
        mirror: true,
      ),
      height: 200,
      width: 200,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
        print('xxx appLifeCycleState inactive');
        break;
      case AppLifecycleState.resumed:
        print('xxx appLifeCycleState resumed');
        break;
      case AppLifecycleState.paused:
        print('xxx appLifeCycleState paused');
        break;
      case AppLifecycleState.detached:
        print('xxx appLifeCycleState detached');
        break;
    }
  }
}
