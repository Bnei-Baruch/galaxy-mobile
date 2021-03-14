import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';
import 'package:janus_client/Plugin.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'components/playerWIdget.dart';

class StreamingUnified extends StatefulWidget {
  int defaultVideo = 15;
  int defaultAudio = 1;
  bool isPlayerShown = false;

  var videoTrack;

  var isVideoPlaying;
  Plugin videoStreamingPlugin;
  Plugin audioStreamingPlugin;

  @override
  _StreamingUnifiedState createState() => _StreamingUnifiedState();

  void exit() {
    videoStreamingPlugin.send(message: {"request": "stop"});
    audioStreamingPlugin.send(message: {"request": "stop"});
  }
}

class _StreamingUnifiedState extends State<StreamingUnified> {
  JanusClient janusClient = JanusClient(iceServers: [
    RTCIceServer(url: "stun:stream.kli.one:3478", username: "", credential: "")
  ], server: [
    "https://str2.kli.one/janustrl"
  ], withCredentials: false, apiSecret: "secret", isUnifiedPlan: true);

  TextEditingController nameController = TextEditingController();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();
  PlayerWidget playerOverlay = PlayerWidget();
  MediaStream _remoteStream;

  List<dynamic> streams = [];
  int selectedStreamId;
  bool _loader = true;

  StateSetter _setState;

  getStreamListing() {
    //should get this list from our server later on
    var body = {"request": "list"};
    widget.videoStreamingPlugin.send(
        message: body,
        onSuccess: () {
          print("listing");
        },
        onError: (e) {
          print('got error in listing');
          print(e);
        });
  }

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    await _remoteRenderer.initialize();
    _remoteStream = await createLocalMediaStream("local");
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    playerOverlay.play = (playing) => {
          widget.audioStreamingPlugin.hangup(),
          widget.videoStreamingPlugin.hangup()
        };
    playerOverlay.audioChange = () {
      //  audioStreamingPlugin.send(message: {"request": "stop"});
      widget.audioStreamingPlugin.send(message: {
        "request": "switch",
        "id": playerOverlay.audioTypeValue["value"]
      });
    };
    playerOverlay.videoChange = () async {
      if (playerOverlay.videoTypeValue["value"] !=
          StreamConstants.NO_VIDEO_OPTION_VALUE) {
        if (widget.videoStreamingPlugin != null &&
            widget.isVideoPlaying == true) {
          widget.videoStreamingPlugin.send(message: {
            "request": "switch",
            "id": playerOverlay.videoTypeValue["value"]
          });
        } else {
          // videoStreamingPlugin.send(message: {
          //   "request": "watch",
          //   "id": playerOverlay.videoTypeValue[
          //       "value"], //playerOverlay.videoTypeValue["value"],
          //   "offer_audio": true,
          //   "offer_video": true,
          // });
          initVideoStream();
        }
      } else {
        // _remoteRenderer.srcObject = null;
        // _remoteRenderer.dispose();
        _remoteRenderer.srcObject = null;
        _remoteStream.removeTrack(_remoteStream.getVideoTracks().first);
        _remoteStream = await createLocalMediaStream("local");

        //_remoteRenderer = new RTCVideoRenderer();
        //await _remoteRenderer.initialize();
        //  _remoteRenderer.srcObject.removeTrack(widget.videoTrack);
        widget.videoStreamingPlugin.send(message: {"request": "stop"});
        widget.videoStreamingPlugin.destroy();
        widget.videoStreamingPlugin = null;
      }
    };
    widget.isPlayerShown = false;
    janusClient.connect(onSuccess: (sessionId) {
      //video plugin init
      initVideoStream();
      //audio plugin init
      janusClient.attach(Plugin(
          onRemoteTrack: (stream, track, mid, on) {
            print('got remote stream');

            playerOverlay.isPlaying = true;
          },
          plugin: "janus.plugin.streaming",
          onMessage: (msg, jsep) async {
            print('got onmsg');
            print(msg);
            if (msg['streaming'] != null && msg['result'] != null) {
              if (msg['streaming'] == 'event' &&
                  msg['result']['status'] == 'stopping') {
                // await this.destroy();
              }
            }

            if (msg['janus'] == 'success' && msg['plugindata'] != null) {
              var plugindata = msg['plugindata'];
              print('got plugin data');
            }

            if (jsep != null) {
              debugPrint("Handling SDP as well..." + jsep.toString());
              await widget.audioStreamingPlugin.handleRemoteJsep(jsep);
              RTCSessionDescription answer =
                  await widget.audioStreamingPlugin.createAnswer();
              widget.audioStreamingPlugin
                  .send(message: {"request": "start"}, jsep: answer);

              // Navigator.of(context).pop();
              setState(() {
                _loader = false;
              });
            }
          },
          onSuccess: (plugin) {
            setState(() {
              widget.audioStreamingPlugin = plugin;
              // this.getStreamListing();
              widget.audioStreamingPlugin.send(message: {
                "request": "watch",
                "id": 15, //playerOverlay.videoTypeValue["value"],
                "offer_audio": true,
                "offer_video": true,
              });
            });
          }));
    });
  }

  void initVideoStream() {
    janusClient.attach(Plugin(
        onRemoteTrack: (stream, track, mid, on) {
          print('got remote stream');
          widget.videoTrack = track;
          _remoteStream
              .addTrack(track)
              .then((value) => _remoteRenderer.srcObject = _remoteStream);
          playerOverlay.isPlaying = true;
          widget.isVideoPlaying = true;
        },
        plugin: "janus.plugin.streaming",
        onMessage: (msg, jsep) async {
          print('got onmsg');
          print(msg);
          if (msg['streaming'] != null && msg['result'] != null) {
            if (msg['streaming'] == 'event' &&
                msg['result']['status'] == 'stopping') {
              // await this.destroy();
              widget.isVideoPlaying = false;
            }
          }

          if (msg['janus'] == 'success' && msg['plugindata'] != null) {
            var plugindata = msg['plugindata'];
            print('got plugin data');
          }

          if (jsep != null) {
            debugPrint("Handling SDP as well..." + jsep.toString());
            await widget.videoStreamingPlugin.handleRemoteJsep(jsep);
            RTCSessionDescription answer =
                await widget.videoStreamingPlugin.createAnswer();
            widget.videoStreamingPlugin
                .send(message: {"request": "start"}, jsep: answer);
            // Navigator.of(context).pop();
            setState(() {
              _loader = false;
            });
          }
        },
        onSuccess: (plugin) {
          setState(() {
            widget.videoStreamingPlugin = plugin;
            // this.getStreamListing();
            widget.videoStreamingPlugin.send(message: {
              "request": "watch",
              "id": 1, //playerOverlay.videoTypeValue["value"],
              "offer_audio": true,
              "offer_video": true,
            });
          });
        }));
  }

  Future<void> cleanUpAndBack() async {
    widget.videoStreamingPlugin.send(message: {"request": "stop"});
    widget.audioStreamingPlugin.send(message: {"request": "stop"});
  }

  destroy() async {
    await widget.videoStreamingPlugin.destroy();
    await widget.audioStreamingPlugin.destroy();
    janusClient.destroy();
    if (_remoteRenderer != null) {
      _remoteRenderer.srcObject = null;
      await _remoteRenderer.dispose();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        dragStartBehavior: DragStartBehavior.down,
        child: Stack(alignment: Alignment.topCenter, children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: MediaQuery.of(context).size.height / 3,
                child: RTCVideoView(
                  _remoteRenderer,
                  mirror: false,
                  // objectFit:
                  //     RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  // RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ],
          ),
          widget.isPlayerShown ? playerOverlay : Container(),
        ]),
        onTap: () {
          setState(() {
            widget.isPlayerShown = !widget.isPlayerShown;
          });
        });
    //
  }

  @override
  void dispose() async {
    // TODO: implement dispose

    super.dispose();
  }
}
