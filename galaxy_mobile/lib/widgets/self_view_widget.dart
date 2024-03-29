import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
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

  void stopCamera() {
    FlutterLogs.logInfo("SelfViewWidget", "stopCamera", "");
    if (state != null
        && state.mounted
        && (state.myStream as MediaStream) != null
        && (state.myStream as MediaStream).getVideoTracks().isNotEmpty ) {
      (state.myStream as MediaStream).getVideoTracks().first.enabled = false;
      (state.myStream as MediaStream).getVideoTracks().first.stop();
    }
  }
  void unMute() {
    FlutterLogs.logInfo("SelfViewWidget", "unmute", "");
    if (state != null
        && state.mounted
        && (state.myStream as MediaStream) != null
        && (state.myStream as MediaStream).getAudioTracks().isNotEmpty ) {
      Helper.setMicrophoneMute(false, (state.myStream as MediaStream).getAudioTracks().first);

    }
  }
}

class _SelfViewWidgetState extends State<SelfViewWidget>
    with WidgetsBindingObserver {
  RTCVideoRenderer _localRenderer;
  Plugin pluginHandle;
  Plugin subscriberHandle;
  MediaStream myStream;

  @override
  void didChangeDependencies() async {
    FlutterLogs.logInfo("SelfViewWidget", "didChangeDependencies", "");

    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    widget.state = this;
    FlutterLogs.logInfo("SelfViewWidget", "initState", "");
    WidgetsBinding.instance.addObserver(this);

    initRenderers();
  }

  @override
  void dispose() {
    FlutterLogs.logInfo("SelfViewWidget", "dispose", "");
  
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  initRenderers() async {
    _localRenderer = new RTCVideoRenderer();
    await _localRenderer.initialize();

    var mediaConstraints = {
      "audio": false,
      "video": {
        "mandatory": {
          "minWidth":
              320, // Provide your own width, height and frame rate here
          "minHeight": 180,
          "minFrameRate": 15,
        },
       "facingMode": "user",
        "optional": [],
      }
    };
    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    myStream = stream;
    setState(() {
      _localRenderer.srcObject = stream;
    });
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
        FlutterLogs.logInfo("SelfViewWidget", "appLifeCycleState", "inactive");
        break;
      case AppLifecycleState.resumed:
        FlutterLogs.logInfo("SelfViewWidget", "appLifeCycleState", "resumed");
        break;
      case AppLifecycleState.paused:
        FlutterLogs.logInfo("SelfViewWidget", "appLifeCycleState", "paused");
        break;
      case AppLifecycleState.detached:
        FlutterLogs.logInfo("SelfViewWidget", "appLifeCycleState", "detached");
        break;
    }
  }
}
