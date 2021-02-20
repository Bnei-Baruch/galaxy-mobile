import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
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
    initRenderers();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    MediaStream stream = await Plugin().initializeMediaDevices();
    myStream = stream;
    myStream.getAudioTracks().first.setMicrophoneMute(false);
    _localRenderer.srcObject = myStream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
              icon: Icon(
                Icons.call,
                color: Colors.greenAccent,
              ),
              onPressed: () async {
                await this.initRenderers();
              }),
          IconButton(
              icon: Icon(
                Icons.call_end,
                color: Colors.red,
              ),
              onPressed: () {
                _localRenderer.srcObject = null;
                _localRenderer.dispose();
                setState(() {});
              }),
          IconButton(
              icon: Icon(
                Icons.switch_camera,
                color: Colors.white,
              ),
              onPressed: () {})
        ],
        title: const Text('janus_client'),
      ),
      body: Container(
        child: RTCVideoView(
          _localRenderer,
        ),
        height: 200,
        width: 200,
      ),
    );
  }
}
