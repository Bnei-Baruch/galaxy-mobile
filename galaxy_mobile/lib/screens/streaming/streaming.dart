import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:janus_client/Plugin.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'components/playerWIdget.dart';

class StreamingUnified extends StatefulWidget {
  int defaultVideo = 15;
  int defaultAudio = 1;
  bool isPlayerShown = false;
  @override
  _StreamingUnifiedState createState() => _StreamingUnifiedState();
}

class _StreamingUnifiedState extends State<StreamingUnified> {
  JanusClient janusClient = JanusClient(iceServers: [
    RTCIceServer(url: "stun:stream.kli.one:3478", username: "", credential: "")
  ], server: [
    "https://str2.kli.one/janustrl"
  ], withCredentials: false, apiSecret: "secret", isUnifiedPlan: true);
  Plugin videoStreamingPlugin;
  Plugin audioStreamingPlugin;
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
    videoStreamingPlugin.send(
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
    playerOverlay.play = (playing) =>
        {audioStreamingPlugin.hangup(), videoStreamingPlugin.hangup()};
    playerOverlay.audioChange = () {
      audioStreamingPlugin.send(message: {"request": "stop"});
      audioStreamingPlugin.send(message: {
        "request": "watch",
        "id": playerOverlay
            .audioTypeValue["value"], //playerOverlay.videoTypeValue["value"],
        "offer_audio": true,
        "offer_video": true,
      });
    };
    widget.isPlayerShown = false;
    janusClient.connect(onSuccess: (sessionId) {
      //video plugin init
      janusClient.attach(Plugin(
          onRemoteTrack: (stream, track, mid, on) {
            print('got remote stream');
            _remoteStream
                .addTrack(track)
                .then((value) => _remoteRenderer.srcObject = _remoteStream);
            playerOverlay.isPlaying = true;
          },
          plugin: "janus.plugin.streaming",
          onMessage: (msg, jsep) async {
            print('got onmsg');
            print(msg);
            if (msg['streaming'] != null && msg['result'] != null) {
              if (msg['streaming'] == 'event' &&
                  msg['result']['status'] == 'stopping') {
                await this.destroy();
              }
            }

            if (msg['janus'] == 'success' && msg['plugindata'] != null) {
              var plugindata = msg['plugindata'];
              print('got plugin data');

              // showDialog(
              //     context: context,
              //     barrierDismissible: false,
              //     child: StatefulBuilder(builder: (context, setstate) {
              //       _setState = setstate;
              //       _setState(() {
              //         streams = plugindata['data']['list'];
              //       });
              //
              //       return AlertDialog(
              //         title: Text("Choose Stream To Play"),
              //         content: Column(
              //           children: [
              //             DropdownButtonFormField(
              //                 isExpanded: true,
              //                 value: selectedStreamId,
              //                 items: List.generate(
              //                     streams.length,
              //                     (index) => DropdownMenuItem(
              //                         value: streams[index]['id'],
              //                         child:
              //                             Text(streams[index]['description']))),
              //                 onChanged: (v) {
              //                   _setState(() {
              //                     selectedStreamId = v;
              //                   });
              //                 }),
              //             RaisedButton(
              //               color: Colors.green,
              //               textColor: Colors.white,
              //               onPressed: () {
              //                 videoStreamingPlugin.send(message: {
              //                   "request": "watch",
              //                   "id": selectedStreamId,
              //                   "offer_audio": true,
              //                   "offer_video": true,
              //                 });
              //               },
              //               child: Text("Play"),
              //             )
              //           ],
              //         ),
              //       );
              //     }));
            }

            if (jsep != null) {
              debugPrint("Handling SDP as well..." + jsep.toString());
              await videoStreamingPlugin.handleRemoteJsep(jsep);
              RTCSessionDescription answer =
                  await videoStreamingPlugin.createAnswer();
              videoStreamingPlugin
                  .send(message: {"request": "start"}, jsep: answer);
              // Navigator.of(context).pop();
              setState(() {
                _loader = false;
              });
            }
          },
          onSuccess: (plugin) {
            setState(() {
              videoStreamingPlugin = plugin;
              // this.getStreamListing();
              videoStreamingPlugin.send(message: {
                "request": "watch",
                "id": 1, //playerOverlay.videoTypeValue["value"],
                "offer_audio": true,
                "offer_video": true,
              });
            });
          }));
      //audio plugin init
      janusClient.attach(Plugin(
          onRemoteTrack: (stream, track, mid, on) {
            print('got remote stream');
            // _remoteStream
            //     .addTrack(track)
            //     .then((value) => _remoteRenderer.srcObject = _remoteStream);
            playerOverlay.isPlaying = true;
          },
          plugin: "janus.plugin.streaming",
          onMessage: (msg, jsep) async {
            print('got onmsg');
            print(msg);
            if (msg['streaming'] != null && msg['result'] != null) {
              if (msg['streaming'] == 'event' &&
                  msg['result']['status'] == 'stopping') {
                await this.destroy();
              }
            }

            if (msg['janus'] == 'success' && msg['plugindata'] != null) {
              var plugindata = msg['plugindata'];
              print('got plugin data');
              // showDialog(
              //     context: context,
              //     barrierDismissible: false,
              //     child: StatefulBuilder(builder: (context, setstate) {
              //       _setState = setstate;
              //       _setState(() {
              //         streams = plugindata['data']['list'];
              //       });
              //
              //       return AlertDialog(
              //         title: Text("Choose Stream To Play"),
              //         content: Column(
              //           children: [
              //             DropdownButtonFormField(
              //                 isExpanded: true,
              //                 value: selectedStreamId,
              //                 items: List.generate(
              //                     streams.length,
              //                     (index) => DropdownMenuItem(
              //                         value: streams[index]['id'],
              //                         child:
              //                             Text(streams[index]['description']))),
              //                 onChanged: (v) {
              //                   _setState(() {
              //                     selectedStreamId = v;
              //                   });
              //                 }),
              //             RaisedButton(
              //               color: Colors.green,
              //               textColor: Colors.white,
              //               onPressed: () {
              //                 audioStreamingPlugin.send(message: {
              //                   "request": "watch",
              //                   "id": selectedStreamId,
              //                   "offer_audio": true,
              //                   "offer_video": true,
              //                 });
              //               },
              //               child: Text("Play"),
              //             )
              //           ],
              //         ),
              //       );
              //     }
              //     )
              // );
            }

            if (jsep != null) {
              debugPrint("Handling SDP as well..." + jsep.toString());
              await audioStreamingPlugin.handleRemoteJsep(jsep);
              RTCSessionDescription answer =
                  await audioStreamingPlugin.createAnswer();
              audioStreamingPlugin
                  .send(message: {"request": "start"}, jsep: answer);
              // Navigator.of(context).pop();
              setState(() {
                _loader = false;
              });
            }
          },
          onSuccess: (plugin) {
            setState(() {
              audioStreamingPlugin = plugin;
              // this.getStreamListing();
              audioStreamingPlugin.send(message: {
                "request": "watch",
                "id": 15, //playerOverlay.videoTypeValue["value"],
                "offer_audio": true,
                "offer_video": true,
              });
            });
          }));
    });
  }

  Future<void> cleanUpAndBack() async {
    videoStreamingPlugin.send(message: {"request": "stop"});
  }

  destroy() async {
    await videoStreamingPlugin.destroy();
    janusClient.destroy();
    if (_remoteRenderer != null) {
      _remoteRenderer.srcObject = null;
      await _remoteRenderer.dispose();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: GestureDetector(
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
            })
        //
        );
  }

  @override
  void dispose() async {
    // TODO: implement dispose
    super.dispose();
  }
}
