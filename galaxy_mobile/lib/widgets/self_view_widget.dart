import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:janus_client/Plugin.dart';

import 'dart:async';

var DEFAULT_MEDIA_CONSTRAINTS = {
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

class MediaStreamController extends ChangeNotifier {
  MediaStream mediaStream;

  bool _isEnabled() => mediaStream != null;

  Future<void> enable() async {
    if (!_isEnabled()) {
      try {
        MediaStream stream =
        await navigator.mediaDevices.getUserMedia(DEFAULT_MEDIA_CONSTRAINTS);
        mediaStream = stream;
      } catch (e) {
        FlutterLogs.logInfo("MediaStreamController",
            "enable",
            "error: ${e.toString()}");
      }
    }
    notifyListeners();
  }

  Future<void> disable() async {
    try {
      await mediaStream?.dispose();
      mediaStream = null;
    } catch (e) {
      FlutterLogs.logInfo("MediaStreamController",
                          "disable",
                          "error: ${e.toString()}");
    }
    notifyListeners();
  }

  @override
  void dispose() {
    mediaStream?.dispose();
    super.dispose();
  }
}

class SelfViewWidget extends StatefulWidget {
  final MediaStreamController mediaStreamController;

  SelfViewWidget({
    this.mediaStreamController,
  }) : assert(mediaStreamController != null);

  @override
  _SelfViewWidgetState createState() => _SelfViewWidgetState();
}

class _SelfViewWidgetState extends State<SelfViewWidget>
    with WidgetsBindingObserver {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    FlutterLogs.logInfo("SelfViewWidget", "initState", "");
    WidgetsBinding.instance.addObserver(this);
    widget.mediaStreamController.addListener(_updateRendererStream);
    initRenderers().then((_) => widget.mediaStreamController.enable());
  }

  @override
  void dispose() {
    FlutterLogs.logInfo("SelfViewWidget", "dispose", "");
  
    WidgetsBinding.instance.removeObserver(this);
    widget.mediaStreamController.removeListener(_updateRendererStream);
    _localRenderer.dispose();
    super.dispose();
  }

  void _updateRendererStream() {
    if (!mounted) {
      return;
    }

    setState(() {
      _localRenderer.srcObject = widget.mediaStreamController.mediaStream;
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
