import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';
import 'package:janus_client/Plugin.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'components/playerWIdget.dart';
import 'package:provider/provider.dart';

class StreamingUnified extends StatefulWidget {
  int defaultVideo = 15;
  int defaultAudio = 1;
  bool isPlayerShown = false;

  var videoTrack;
  var audioTrack;
  var audioStream;

  var isVideoPlaying;
  Plugin videoStreamingPlugin;
  Plugin audioStreamingPlugin;

  bool initialized = false;
  bool connected = false;

  _StreamingUnifiedState state;

  @override
  _StreamingUnifiedState createState() => _StreamingUnifiedState();

  void exit() {
    if (videoStreamingPlugin != null) {
      videoStreamingPlugin.send(message: {"request": "stop"});
      videoStreamingPlugin.hangup();
      videoStreamingPlugin.destroy();
    }
    if (audioStreamingPlugin != null) {
      audioStreamingPlugin.send(message: {"request": "stop"});
      audioStreamingPlugin.hangup();
      audioStreamingPlugin.destroy();
    }
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
  MediaStream _remoteStreamAudio;

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
          FlutterLogs.logInfo("Streaming", "getStreamListing", "listing");
        },
        onError: (e) {
          FlutterLogs.logInfo("Streaming", "getStreamListing",
              "error occurred during listing: $e");
        });
  }

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    await _remoteRenderer.initialize();
    // _remoteStreamAudio = await createLocalMediaStream("local");
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    widget.state = this;
//set user preset of audio and video
    final int audio =
        Provider.of<MainStore>(context, listen: false).audioPreset;
    final int video =
        Provider.of<MainStore>(context, listen: false).videoPreset;
    playerOverlay.audioPreset = audio;
    playerOverlay.videoPreset = video;
    playerOverlay.setStreamPresets(audio, video);

    playerOverlay.play = (playing) {
      if (!playing) {
        if (widget.videoStreamingPlugin != null)
          widget.videoStreamingPlugin.send(message: {"request": "stop"});
        widget.audioStreamingPlugin.send(message: {"request": "stop"});
        _remoteStreamAudio = null;
        setState(() {
          widget.isVideoPlaying = playing;
        });
      } else {
        // widget.videoStreamingPlugin.send(message: {
        //   "request": "watch",
        //   "id": 1, //playerOverlay.videoTypeValue["value"],
        //   "offer_audio": true,
        //   "offer_video": true,
        // });
        // widget.audioStreamingPlugin.send(message: {
        //   "request": "watch",
        //   "id": 15, //playerOverlay.videoTypeValue["value"],
        //   "offer_audio": true,
        //   "offer_video": true,
        // });
        initAudioStream();
        initVideoStream();
      }
    };

    playerOverlay.mute = (muted) {
      FlutterLogs.logInfo("Streaming", "&&&&&&&&&&&&&&&&",
          "playerOverlay.mute: ${muted.toString()}");
      _remoteStreamAudio.getAudioTracks().last.enabled =
          !muted; //.setVolume(muted ? 0 : 0.5);
    };

    playerOverlay.audioChange = () {
      context
          .read<MainStore>()
          .setAudioPreset(playerOverlay.audioTypeValue["value"]);
      // context.select((MainStore s) =>
      //     s.audioPreset = playerOverlay.audioTypeValue["value"]);
      widget.audioStreamingPlugin.send(message: {
        "request": "switch",
        "id": playerOverlay.audioTypeValue["value"]
      });
    };
    playerOverlay.videoChange = () async {
      context
          .read<MainStore>()
          .setVideoPreset(playerOverlay.videoTypeValue["value"]);
      // context.select((MainStore s) =>
      //     s.videoPreset = playerOverlay.videoTypeValue["value"]);
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
        // _remoteStreamAudio
        //     .removeTrack(_remoteStreamAudio.getVideoTracks().first);
        // _remoteStreamAudio = await createLocalMediaStream("local");

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
      widget.connected = true;
      setState(() {});
    });
  }

  void initAudioStream() {
    janusClient.attach(Plugin(
        onRemoteTrack: (stream, track, mid, on) {
          FlutterLogs.logInfo(
              "Streaming", "initAudioStream", "got remote stream");
          widget.audioTrack = track;
          _remoteStreamAudio = stream;
          // _remoteStreamAudio.addTrack(track);
          // widget.audioStream = stream;
          playerOverlay.isPlaying = true;
        },
        plugin: "janus.plugin.streaming",
        onMessage: (msg, jsep) async {
          FlutterLogs.logInfo(
              "Streaming", "initAudioStream", "got onmsg: $msg");
          if (msg['streaming'] != null && msg['result'] != null) {
            if (msg['streaming'] == 'event' &&
                msg['result']['status'] == 'stopping') {
              // await this.destroy();
            }
          }

          if (msg['janus'] == 'success' && msg['plugindata'] != null) {
            var plugindata = msg['plugindata'];
            FlutterLogs.logInfo(
                "Streaming", "initAudioStream", "got plugin data");
          }

          if (jsep != null) {
            String jsepStr = jsep.toString();
            FlutterLogs.logInfo("Streaming", "initAudioStream",
                "Handling SDP as well... $jsepStr");
            // debugPrint("Handling SDP as well..." + jsep.toString());
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
            //     this.getStreamListing();
            widget.audioStreamingPlugin.send(message: {
              "request": "watch",
              "id": playerOverlay.audioTypeValue["value"], //15, //
              "offer_audio": true,
              "offer_video": true,
            });
          });
        }));
  }

  void initVideoStream() {
    janusClient.attach(Plugin(
        onRemoteTrack: (stream, track, mid, on) {
          FlutterLogs.logInfo(
              "Streaming", "initVideoStream", "got remote stream");
          widget.videoTrack = track;
          // _remoteStreamAudio.addTrack(track);
          //     .then((value) =>

          _remoteRenderer.srcObject = stream;
          playerOverlay.isPlaying = true;
          setState(() {
            widget.isVideoPlaying = true;
          });
        },
        plugin: "janus.plugin.streaming",
        onMessage: (msg, jsep) async {
          FlutterLogs.logInfo(
              "Streaming", "initVideoStream", "got onmsg: $msg");
          if (msg['streaming'] != null && msg['result'] != null) {
            if (msg['streaming'] == 'event' &&
                msg['result']['status'] == 'stopping') {
              // await this.destroy();
              if (mounted) {
                setState(() {
                  widget.isVideoPlaying = false;
                });
              }
            }
          }

          if (msg['janus'] == 'success' && msg['plugindata'] != null) {
            var plugindata = msg['plugindata'];
            FlutterLogs.logInfo(
                "Streaming", "initVideoStream", "got plugin data");
          }

          if (jsep != null) {
            String jsepStr = jsep.toString();
            FlutterLogs.logInfo("Streaming", "initVideoStream",
                "Handling SDP as well... $jsepStr");
            // debugPrint("Handling SDP as well..." + jsep.toString());
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
              "id": playerOverlay.videoTypeValue["value"], //1, //
              "offer_audio": true,
              "offer_video": true,
            });
          });
        }));
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
    if (widget.connected && !widget.initialized) {
      FlutterLogs.logInfo("Streaming", "build", "initializing");
      widget.initialized = true;
      //video plugin init
      initVideoStream();
      //audio plugin init
      initAudioStream();
    }
    return GestureDetector(
        dragStartBehavior: DragStartBehavior.down,
        child: Stack(alignment: Alignment.topCenter, children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: MediaQuery.of(context).size.height / 3,
                child:
                    (_remoteRenderer.srcObject != null && widget.isVideoPlaying)
                        ? RTCVideoView(
                            _remoteRenderer,
                            mirror: false,
                            // objectFit:
                            //     RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                            // RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          )
                        : InkWell(
                            onTap: () {
                              setState(() {
                                widget.isPlayerShown = !widget.isPlayerShown;
                              });
                            },
                            child: Container(
                                height: MediaQuery.of(context).size.height / 3,
                                width: MediaQuery.of(context).size.width,
                                child: Center(
                                    child: Text(
                                  "No video",
                                  style: TextStyle(fontSize: 24),
                                )))),
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
//code for handlking audio out command -- during question
// streamGalaxy = (talk, col, name) => {
// console.log("streamGalaxy", talk, col, name);
// if (!this.isInitialized_()) {
// return;
// }
// if (talk) {
// this.mixvolume = this.audioElement.volume;
// this.talking = true;
// this.trlAudioElement.volume = this.mixvolume;
// this.trlAudioElement.muted = false;
//
// this.prevAudioVolume = this.audioElement.volume;
// this.prevMuted = this.audioElement.muted;
//
// console.log(" :: Switch STR Stream: ", gxycol[col]);
// this.audioJanusStream.send({message: {request: "switch", id: gxycol[col]}});
// const id = trllang[localStorage.getItem("vrt_langtext")];
// console.log(":: Select TRL: ", localStorage.getItem("vrt_langtext"), id);
// if (!id) {
// console.log(" :: Not TRL Stream attach");
// } else {
// this.trlAudioJanusStream.send({message: {request: "switch", id: id}});
// this.talking = setInterval(this.ducerMixaudio, 200);
// console.log(" :: Init TRL Stream: ", localStorage.getItem("vrt_langtext"), id);
// }
// Janus.log("You now talking");
// } else if (this.talking) {
// Janus.log("Stop talking");
// if (this.talking) {
// clearInterval(this.talking);
// }
// this.audioElement.volume = this.mixvolume;
// const id = Number(localStorage.getItem("vrt_lang")) || 2;
// console.log(" :: Switch STR Stream: ", localStorage.getItem("vrt_lang"), id);
// this.audioJanusStream.send({message: {request: "switch", id: id}});
// console.log(" :: Stop TRL Stream: ");
// this.trlAudioElement.muted = true;
// this.talking = null;
// this.mixvolume = null;
// }
// if (this.onTalkingCallback) {
// this.onTalkingCallback(this.talking);
// }
// };
//
// ducerMixaudio = () => {
// if (this.isInitialized_()) {
// // Get remote volume of translator stream (FYI in case of Hebrew, this will be 0 - no translation).
// this.trlAudioJanusStream.getVolume(null, (volume) => {
// if (volume === -1) {
// if (this.talking) {
// clearInterval(this.talking);
// return;
// }
// }
// if (this.prevAudioVolume !== this.audioElement.volume || this.prevMuted !== this.audioElement.muted) {
// // This happens only when user changes audio, update mixvolume.
// this.mixvolume = this.audioElement.muted ? 0 : this.audioElement.volume;
// this.trlAudioElement.volume = this.mixvolume;
// }
// if (volume > 0.05) {
// // If translator is talking (remote volume > 0.05) we want to reduce Rav to 5%.
// this.audioElement.volume = this.mixvolume * 0.05;
// } else if (this.audioElement.volume + 0.01 <= this.mixvolume) {
// // If translator is not talking or no translation (Hebrew) we want to slowly raise
// // sound levels of original source up to original this.mixvolume.
// this.audioElement.volume = this.audioElement.volume + 0.01;
// }
// // Store volume and mute values to be able to detect user volume change.
// this.prevAudioVolume = this.audioElement.volume;
// this.prevMuted = this.audioElement.muted;
// });
// }
// };
