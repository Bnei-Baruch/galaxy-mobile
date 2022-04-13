import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/Plugin.dart';

import 'dart:async';

class SelfViewWidget extends StatefulWidget {
  @override
  _SelfViewWidgetState createState() => _SelfViewWidgetState();

  var state;
  void restartCamera() {
    if (state != null && state.mounted) {
      FlutterLogs.logInfo("SelfViewWidget", "restartCamera", "state mounted, activating camera.");
      state.activateCamera();
    }
  }

  void stopCamera() {
    FlutterLogs.logInfo("SelfViewWidget", "stopCamera", "");
    if (state != null && state.mounted) {
      state.stopCamera();
    }
  }
}

class _SelfViewWidgetState extends State<SelfViewWidget>
    with WidgetsBindingObserver {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
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

    initRenderers().then((_) => activateCamera());
  }

  @override
  void dispose() {
    FlutterLogs.logInfo("SelfViewWidget", "dispose", "");
  
    WidgetsBinding.instance.removeObserver(this);
    _localRenderer.dispose();
    super.dispose();
  }

  Future<void> stopCamera() async {
    try {
      await myStream?.dispose();

      if (!mounted) {
        return;
      }

      setState(() {
        _localRenderer.srcObject = null;
      });
    } catch (e) {
      FlutterLogs.logInfo("_SelfViewWidgetState", "stopCamera", "error: ${e.toString()}");
    }
  }

  Future<void> activateCamera() async {
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

    try {
      MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      myStream = stream;
    } catch (e) {
      FlutterLogs.logInfo("_SelfViewWidgetState", "activateCamera", "error: ${e.toString()}");
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _localRenderer.srcObject = myStream;
    });
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
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
