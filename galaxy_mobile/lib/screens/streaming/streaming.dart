import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/main_store.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';
import 'package:galaxy_mobile/services/mqtt_client.dart';
import 'package:janus_client/Plugin.dart';
import 'package:janus_client/janus_client.dart';
import 'package:janus_client/utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mqtt5_client/mqtt5_client.dart';

import 'components/player_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class StreamingUnified extends StatefulWidget {
  int defaultVideo = 15;
  int defaultAudio = 1;
  bool isPlayerShown = false;
  bool isOnAir = false;

  BooleanCallback fullscreen;

  final double DEFAULT_VOLUME = 0.6;

  var videoTrack;
  var audioTrack;
  var audioStream;

  var isVideoPlaying;
  var isStreamIsPlaying;
  Plugin videoStreamingPlugin;
  Plugin audioStreamingPlugin;
  Plugin audioTrlStreamingPlugin;

  bool initialized = false;
  bool connected = false;
  bool audioMode = false;
  bool isFullScreen = false;

  _StreamingUnifiedState state;

  var mixvolume;

  var trlAudioVolume;

  bool trlAudioMuted;

  var prevAudioVolume;

  bool prevMuted;

  MediaStreamTrack audioTrlTrack;
  Timer ducerMix;

  double audioElementVolume = 0.6;

  bool audioElementMuted = false;

  double trlAudioElementVolume = 0.6;

  @override
  _StreamingUnifiedState createState() => _StreamingUnifiedState();

  void showBar() {
    state.setState(() {
      isPlayerShown = true;
    });
  }

  void hideBar() {
    if (state.mounted) {
      state.setState(() {
        isPlayerShown = false;
      });
    }
  }

  void toggleOnAir(var data) {
    if (state != null && state.mounted) {
      state.setState(() {
        isOnAir = data["status"];
      });
    } else {
      isOnAir = data["status"];
    }

    // todo: handle streams
    handleStreamWhenOnAir(isOnAir);
  }

  void exit() {
    if (videoStreamingPlugin != null) {
      videoStreamingPlugin.send(message: {"request": "stop"});
      videoStreamingPlugin.destroy();
    }
    if (audioStreamingPlugin != null) {
      audioStreamingPlugin.send(message: {"request": "stop"});
      audioStreamingPlugin.destroy();
    }
    if (audioTrlStreamingPlugin != null) {
      audioTrlStreamingPlugin.send(message: {"request": "stop"});
      audioTrlStreamingPlugin.destroy();
    }
  }

  void toggleAudioMode() {
    if (!audioMode) {
      if (videoStreamingPlugin != null) {
        videoStreamingPlugin.send(message: {"request": "stop"});
        videoStreamingPlugin.destroy();
        videoStreamingPlugin = null;
        audioMode = true;
        state.setState(() {
          isVideoPlaying = false;
        });
      }
    } else {
      audioMode = false;
      state.getPresets();
      state.initVideoStream();
    }
  }

  void handleStreamWhenOnAir(bool isOnAir) {
    FlutterLogs.logInfo(
        "Streaming", "handle question", "handleStreamWhenOnAir $isOnAir");

    if (isOnAir) {
      this.mixvolume = DEFAULT_VOLUME; // getting current volume
      //this.isOnAir = true; //settign status to talking - do we need?
      this.trlAudioVolume = this.mixvolume; // setting translkation volume
      this.trlAudioMuted = false; // enabling translation

      this.prevAudioVolume =
          DEFAULT_VOLUME; // keeping vol for recover when done
      this.prevMuted = state._remoteStreamAudio
          .getAudioTracks()
          .first
          .enabled; // keeping mute state for recover

      FlutterLogs.logInfo("Streaming", "handle question ",
          "Switch STR Stream:${StreamConstants.gxycol[4]}");
      audioStreamingPlugin.send(message: {
        "request": "switch",
        "id": StreamConstants.gxycol[4]
      }); //setting rav only stream
      audioTrlStreamingPlugin.send(message: {
        "request": "switch",
        "id": getTrlLang()
      }); //setting trl stream
      state._remoteTrlStreamAudio.getAudioTracks().first.enabled =
          !trlAudioMuted;

      ducerMix = Timer.periodic(Duration(milliseconds: 200), (timer) {
        ducerMixaudio();
      });
    } else {
      FlutterLogs.logInfo(
          "Streaming", "handle question ", "Switc back to original streams");
      if (ducerMix != null) {
        ducerMix.cancel();
        audioStreamingPlugin.send(message: {
          "request": "switch",
          "id": state.playerOverlay.audioTypeValue["value"]
        }); //set
        this.trlAudioMuted = true; // disbaling translation
        state._remoteTrlStreamAudio.getAudioTracks().last.enabled = false;
        trlAudioMuted = true;

        Helper.setVolume(DEFAULT_VOLUME, state._remoteStreamAudio
        .getAudioTracks()
        .last);
        audioTrlStreamingPlugin.send(message: {"request": "stop"});
        audioTrlStreamingPlugin.destroy();
      }
    }
  }

  int getTrlLang() {
    return StreamConstants.trllang[state.playerOverlay.audioTypeValue["text"]];
  }

  void ducerMixaudio() async {
    FlutterLogs.logInfo("Streaming", "handle question ", "ducerMixaudio");

    // This happens only when user changes audio, update mixvolume.
    var reports = await audioTrlStreamingPlugin
        .getStats(state._remoteTrlStreamAudio.getAudioTracks().first);

    // .then((reports) => () {
    FlutterLogs.logInfo("Streaming", "handle question ", "got reports");
    reports.forEach((element) {
      if (element.values.keys.contains("audioOutputLevel")) {
        double audioLevel =
            (double.parse(element.values["audioOutputLevel"])) / 32768.0;
        FlutterLogs.logInfo("Streaming", "handle question ",
            "ducerMixaudio _remoteTrlStreamAudio=$audioLevel");
        trlAudioElementVolume = audioLevel;
      }
    });

    if (this.prevAudioVolume != this.audioElementVolume ||
        this.prevMuted != this.audioElementMuted) {
      this.mixvolume = this.audioElementMuted ? 0 : this.audioElementVolume;
      this.trlAudioElementVolume = this.mixvolume;

      Helper.setVolume(trlAudioElementVolume, state._remoteTrlStreamAudio
        .getAudioTracks()
        .last);
    }
    if (trlAudioElementVolume > 0.05) {
      // If translator is talking (remote volume > 0.05) we want to reduce Rav to 5%.
      this.audioElementVolume = this.mixvolume * 0.05;
    } else if (this.audioElementVolume + 0.01 <= this.mixvolume) {
      // If translator is not talking or no translation (Hebrew) we want to slowly raise
      // sound levels of original source up to original this.mixvolume.
      this.audioElementVolume = this.audioElementVolume + 0.01;
    }
    // Store volume and mute values to be able to detect user volume change.
    this.prevAudioVolume = this.audioElementVolume;
    this.prevMuted = this.audioElementMuted;

    FlutterLogs.logInfo("Streaming", "handle question ",
        "ducerMixaudio audioElementVolume=$audioElementVolume");
    Helper.setVolume(audioElementVolume,  state._remoteStreamAudio
        .getAudioTracks()
        .last);

        // .setVolume(audioElementVolume);
    // state._remoteTrlStreamAudio.getAudioTracks().first.setVolume(0.6);
    // state._remoteStreamAudio.getAudioTracks().first.setVolume(0.06);
    // });
  }
}

double getAudioLevelofTrack(MediaStreamTrack track) {}

class _StreamingUnifiedState extends State<StreamingUnified> {
  JanusClient janusClient;
  TextEditingController nameController = TextEditingController();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();
  PlayerWidget playerOverlay = PlayerWidget();
  MediaStream _remoteStreamAudio;

  List<dynamic> streams = [];
  int selectedStreamId;
  bool _loader = true;

  StateSetter _setState;

  Orientation _orientation;

  MediaStream _remoteTrlStreamAudio;

  final double playerControlsHeight = 50;

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
    FlutterLogs.logInfo("Streaming", "initState", "enter");
    super.initState();

    final s = context.read<MainStore>();
    janusClient = JanusClient(iceServers: [
      RTCIceServer(
          url: "stun:stream.kli.one:3478", username: "", credential: "")
    ], server: [
      s.activeStreamGateway.url // "https://str2.kli.one/janustrl" //
      // "https://gxydev.kli.one/janusgxy"
    ], withCredentials: false, apiSecret: "secret", isUnifiedPlan: true);
    widget.audioMode = s.audioMode;
    widget.state = this;
    widget.trlAudioMuted = true;
    widget.isVideoPlaying = false;
//set user preset of audio and video
    getPresets();

    playerOverlay.play = (playing) {
      FlutterLogs.logInfo("Streaming", "play", "request to $playing");
      if (!playing) {
        if (widget.videoStreamingPlugin != null)
          widget.videoStreamingPlugin.send(message: {"request": "stop"});
        _remoteStreamAudio.getAudioTracks().last.stop();
        _remoteStreamAudio.getAudioTracks().last.enabled = false;
        _remoteStreamAudio.dispose();
        widget.audioStreamingPlugin.send(message: {"request": "stop"});
        widget.audioStreamingPlugin.destroy();
        //  widget.audioTrlStreamingPlugin.send(message: {"request": "stop"});
        _remoteStreamAudio = null;
        setState(() {
          widget.isVideoPlaying = playing;
        });
      } else {
        initAudioStream();

        initVideoStream();
      }
    };

    playerOverlay.fullScreen = (fullscreen) {
      widget.fullscreen(fullscreen);
      widget.isFullScreen = fullscreen;
      initVideoStream();
      setState(() {});
    };

    playerOverlay.mute = (muted) {
      FlutterLogs.logInfo("Streaming", "&&&&&&&&&&&&&&&&",
          "playerOverlay.mute: ${muted.toString()},  ${_remoteStreamAudio.getAudioTracks().last.id}");
      _remoteStreamAudio.getAudioTracks().last.enabled =
          !muted; //.setVolume(muted ? 0 : 0.5);
      // FlutterLogs.logInfo("Streaming", "&&&&&&&&&&&&&&&&", "audio trl");
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
    registerMQTTTopics();
    if (janusClient.mqttSender != null) {
      context.read<MQTTClient>().addOnSubscribedCallback((topic) => {
        if (topic.contains("from-janus") &&
           janusClient.status.isEmpty)
          janusConnect()
      });
    } else {
      janusConnect();
    }

  }

  void janusConnect() {
    janusClient.connect(onSuccess: (sessionId) {
      widget.connected = true;
      setState(() {});
    });
  }

  void registerMQTTTopics() {
    var stream = context.read<MainStore>().activeStreamGateway;
    String rxTopicUser = 'janus/' + stream.name + '/from-janus' + "/" + context.read<MainStore>().activeUser.id;
    String rxTopic = 'janus/' + stream.name + '/from-janus';
    String txTopic = 'janus/' + stream.name + '/to-janus';
    String stTopic = 'janus/' + stream.name + '/status';


    context.read<MQTTClient>().subscribe(rxTopicUser);
    context.read<MQTTClient>().subscribe(rxTopic);

    context.read<MQTTClient>().subscribe(stTopic);
    context.read<MQTTClient>().addOnMsgReceivedCallback((payload, topic) => janusClient.onMessage(payload, topic));
    janusClient.mqttSender = (msg) {
      var correlationData = parse(msg)["transaction"];
      // let cd = correlationData ? " | transaction: " + correlationData : ""
      // log.debug("%c[mqtt] --> send message" + cd + " | topic: " + topic + " | data: " + message, "color: darkgrey");
      var container =  MqttPropertyContainer();
      var resTopicProp = MqttUtf8StringProperty();
      resTopicProp.identifier = MqttPropertyIdentifier.responseTopic;
      resTopicProp.value = rxTopic;

      var correlationProp = MqttUtf8StringProperty();
      correlationProp.identifier = MqttPropertyIdentifier.correlationdata;
      correlationProp.value = correlationData;
      container.add(correlationProp);

      var userProp = MqttUserProperty();
      userProp.identifier = MqttPropertyIdentifier.userProperty;
      userProp.pairValue = context.read<MainStore>().activeUser.toJson().toString();
      userProp.pairName = "userProperties";
      container.add(userProp);




      //   var properties = rxTopic.isEmpty ? MqttPropertyContainer().userProperties.add(MqttUserProperty())//{userProperties: user || this.user, responseTopic: rxTopic, correlationData} : {userProperties: user || this.user};
      // let options = {qos: 1, retain, properties};
      // this.mq.publish(topic, message, {...options}, (err) => {



      // context.read<MQTTClient>().send(txTopic, msg,retain: false,container);

      MqttPublishMessage message = MqttPublishMessage();
      message.withResponseTopic(rxTopicUser).withResponseCorrelationdata(MqttByteBuffer.fromList(correlationData.codeUnits).buffer).withUserProperties(container.userProperties).withQos(MqttQos.atLeastOnce);
      message.toTopic(txTopic);
      var payload = MqttPublishPayload();

      var jsonBytes = utf8.encode(msg);
      JsonEncoder encoder = JsonEncoder();
      var res =  encoder.convert(jsonBytes);
      payload.message = MqttByteBuffer.fromList(jsonBytes).buffer;

      message.payload = payload;
      // Timer(Duration(seconds:2),() {
      //

      context.read<MQTTClient>().sendPublishMessage(message);


      print("xxx msg send $msg to server ${stream.url}");
      print("xxx msg send  after inversion ${MqttUtilities.bytesToStringAsString(payload.message)}");
      // });
    };

  }

  void unRegisterMqtt() {
    var stream = context.read<MainStore>().activeStreamGateway;
    String rxTopicUser = 'janus/' + stream.name + '/from-janus' + "/" + context.read<MainStore>().activeUser.id;
    String rxTopic = 'janus/' + stream.name + '/from-janus';

    String stTopic = 'janus/' + stream.name + '/status';



    context.read<MQTTClient>().unsubscribe(rxTopic);
    context.read<MQTTClient>().unsubscribe(rxTopicUser);
    context.read<MQTTClient>().unsubscribe(stTopic);
    context.read<MQTTClient>().removeOnMsgReceivedCallback((payload, topic) => janusClient.onMessage(payload, topic));
    janusClient.mqttSender = null;
  }
  void getPresets() {
    FlutterLogs.logInfo("Streaming", "getPresets", "enter");
    final int audio =
        Provider.of<MainStore>(context, listen: false).audioPreset;
    int video = Provider.of<MainStore>(context, listen: false).videoPreset;

    if (widget.audioMode) {
      video = StreamConstants.NO_VIDEO_OPTION_VALUE;
    }

    playerOverlay.audioPreset = audio;
    playerOverlay.videoPreset = video;
    playerOverlay.setStreamPresets(audio, video);
  }

  void initAudioStream() {
    janusClient.attach(Plugin(
        onRemoteTrack: (stream, track, mid, on) {
          FlutterLogs.logInfo(
              "Streaming", "initAudioStream", "got remote stream $track");
          widget.audioTrack = track;
          _remoteStreamAudio = stream;
          // _remoteStreamAudio.addTrack(track);
          // widget.audioStream = stream;
          playerOverlay.isPlaying = true;
        },
        plugin: "janus.plugin.streaming",
        opaqueId: "audiostream-" + randomString(12),
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
        },
        slowLink: (uplink, lost, mid) {
          FlutterLogs.logWarn(
              "Streaming",
              "plugin: audio janus.plugin.streaming",
              "slowLink: uplink ${uplink} lost ${lost} mid ${mid}");
        }));
  }

  String randomString(int len) {
    var charSet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    var randomString = '';
    for (var i = 0; i < len; i++) {
      var randomPoz = (Random().nextDouble() * charSet.length).floor();
      randomString += charSet.substring(randomPoz, randomPoz + 1);
    }
    return randomString;
  }

  void initTrlAudioStream() {
    janusClient.attach(Plugin(
        onRemoteTrack: (stream, track, mid, on) {
          FlutterLogs.logInfo("Streaming", "initTrlAudioStream",
              "got remote trl stream enabling : ${!widget.trlAudioMuted}, track:$track");
          widget.audioTrlTrack = track;
          _remoteTrlStreamAudio = stream;
        },
        plugin: "janus.plugin.streaming",
        opaqueId: "trlstream", //+ randomString(12),
        onMessage: (msg, jsep) async {
          FlutterLogs.logInfo(
              "Streaming", "initTrlAudioStream", "got onmsg: $msg");
          if (msg['streaming'] != null && msg['result'] != null) {
            if (msg['streaming'] == 'event' &&
                msg['result']['status'] == 'stopping') {
              // await this.destroy();
            }
            if (msg['streaming'] == 'event' &&
                msg['result']['status'] == 'switched') {
              _remoteTrlStreamAudio.getAudioTracks().last.enabled =
                  !widget.trlAudioMuted;
            }
            if (msg['streaming'] == 'event' &&
                msg['result']['status'] == 'started') {
              FlutterLogs.logInfo("Streaming", "initTrlAudioStream",
                  "disabling trl stream track count ${_remoteTrlStreamAudio.getAudioTracks().length}");
              _remoteTrlStreamAudio.getAudioTracks().last.enabled = false;
             Helper.setVolume(0, _remoteTrlStreamAudio.getAudioTracks().last);
            }
          }

          if (msg['janus'] == 'success' && msg['plugindata'] != null) {
            var plugindata = msg['plugindata'];
            FlutterLogs.logInfo(
                "Streaming", "initTrlAudioStream", "got plugin data");
          }

          if (jsep != null) {
            String jsepStr = jsep.toString();
            FlutterLogs.logInfo("Streaming", "initTrlAudioStream",
                "Handling SDP as well... $jsepStr");
            // debugPrint("Handling SDP as well..." + jsep.toString());
            await widget.audioTrlStreamingPlugin.handleRemoteJsep(jsep);
            RTCSessionDescription answer =
                await widget.audioTrlStreamingPlugin.createAnswer();
            widget.audioTrlStreamingPlugin
                .send(message: {"request": "start"}, jsep: answer);

            // Navigator.of(context).pop();
            setState(() {
              _loader = false;
            });
          }
        },
        onSuccess: (plugin) {
          setState(() {
            widget.audioTrlStreamingPlugin = plugin;
            //     this.getStreamListing();
            widget.audioTrlStreamingPlugin.send(message: {
              "request": "watch",
              "id": 301, //playerOverlay.audioTypeValue["value"], //15, //
              "offer_audio": true,
              "offer_video": true,
            });
          });
        },
        slowLink: (uplink, lost, mid) {
          FlutterLogs.logWarn(
              "initTrlAudioStream",
              "plugin: audio janus.plugin.streaming",
              "slowLink: uplink ${uplink} lost ${lost} mid ${mid}");
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
        opaqueId: "videostream-" + randomString(12),
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
        },
        slowLink: (uplink, lost, mid) {
          FlutterLogs.logWarn(
              "Streaming",
              "plugin: video janus.plugin.streaming",
              "slowLink: uplink ${uplink} lost ${lost} mid ${mid}");
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

  double getHeight() {
    if (_orientation == null) {
      _orientation = MediaQuery.of(context).orientation;
    } else if (_orientation != MediaQuery.of(context).orientation) {
      FlutterLogs.logInfo("Streaming", "getHeight", "orientation changed");
      _orientation = MediaQuery.of(context).orientation;
    }

    final navBarHeigh = 86;

    double height = MediaQuery.of(context).size.height;
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? height / 3 - playerControlsHeight
        : widget.isFullScreen
            ? height
            : height - navBarHeigh - (playerControlsHeight * 2);
  }

  double getWidth() {
    double width = MediaQuery.of(context).size.width;
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? width
        : widget.isFullScreen
            ? width
            : width / 2;
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
      //audio trl init
      initTrlAudioStream();
    }
    return Stack(
      alignment: Alignment.topCenter,
      children: [
      Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: getHeight(),
            width: getWidth(),
            decoration: BoxDecoration(
                border: Border.all(
                    color:
                        widget.isOnAir ? Colors.redAccent : Colors.transparent,
                    width: 3)),
            child: (_remoteRenderer.srcObject != null && widget.isVideoPlaying)
                ? RTCVideoView(
                    _remoteRenderer,
                    mirror: false,
                    // objectFit:
                        // RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    // RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Material(
                    child: InkWell(
                        onTap: () {
                          setState(() {
                            widget.isPlayerShown = !widget.isPlayerShown;
                          });
                        },
                        child: Container(
                          height: MediaQuery.of(context).size.height / 3,
                          width: MediaQuery.of(context).size.width,
                          child: playerOverlay.isPlaying
                              ? Icon(
                                  Icons.graphic_eq,
                                  size: 150.0,
                                  color: Colors.grey,
                                )
                              : GestureDetector(
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: 150.0,
                                    color: Colors.grey,
                                  ),
                                  onTap: () {
                                    initAudioStream();

                                    initVideoStream();
                                  },
                                ),
                        ))),
          ),
          Container(
            height: playerControlsHeight,
            width: getWidth(),
            child: widget.isPlayerShown ? playerOverlay : Container(),
          )
        ],
      ),
      Align(
          alignment: Alignment.topRight,
          child: Container(
              margin: const EdgeInsets.only(top: 8.0, right: 8.0),
              child: Opacity(
                  opacity: widget.isOnAir ? 1.0 : 0.0,
                  child: Image.asset('assets/graphics/onAir.png',
                      height: 50, fit: BoxFit.fill))))
    ]);
    //
  }

  @override
  void dispose() async {
    // TODO: implement dispose

    super.dispose();
  }
}
