import 'dart:async';
import 'dart:convert';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/screens/streaming/streaming.dart';
import 'package:galaxy_mobile/screens/video_room/videoRoomWidget.dart';
import 'package:flutter_audio_manager/flutter_audio_manager.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:galaxy_mobile/widgets/loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../services/authService.dart';
import 'package:phone_state_i/phone_state_i.dart';

enum AudioDevice { receiver, speaker, bluetooth }

class Dashboard extends StatefulWidget {
  bool audioMute = true;
  bool videoMute = true;
  AudioDevice _audioDevice = AudioDevice.receiver;

  _DashboardState state;

  bool hadNoConnection = false;

  BuildContext dialogPleaseWaitContext;

  VoidCallback callReneter;

  @override
  State createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  var stream = StreamingUnified();
  var videoRoom = VideoRoom();
  var activeUser;
  bool callInProgress;
  MQTTClient _mqttClient;

  String _activeRoomId;

  AudioInput _currentInput = AudioInput("unknow", 0);
  List<AudioInput> _availableInputs = [];

  StreamSubscription<ConnectivityResult> subscription;

  StreamSubscription streamSubscription;

  @override
  void initState() {
    // TODO: implement initState
    widget.state = this;
    callInProgress = false;
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      // Got a new connectivity status!
      FlutterLogs.logInfo("Dashboard", "ConnectivityResult", result.toString());
      //if connection is none or type has changed we restart the room
      if (result == ConnectivityResult.none) {
        //mark no connection
        FlutterLogs.logInfo("Dashboard", "ConnectivityResult", "no connection");

        widget.hadNoConnection = true;
        showDialog(
            context: context,
            useRootNavigator: false,
            barrierDismissible: false,
            builder: (BuildContext context) {
              widget.dialogPleaseWaitContext = context;
              return WillPopScope(
                  onWillPop: () {
                    Navigator.of(widget.state.context).pop();
                    return Future.value(true);
                  },
                  child: Dialog(
                      backgroundColor: Colors.transparent,
                      child: LoadingIndicator(
                          text: "No Internet...reconnecting")));
            });
        Future.delayed(const Duration(seconds: 30), () {
          if (widget.dialogPleaseWaitContext != null) {
            stream.exit();
            videoRoom.exitRoom();
            if (_mqttClient != null) _mqttClient.disconnect();
            Navigator.pop(widget.dialogPleaseWaitContext);
            Navigator.of(widget.state.context).pop();
          }
        });
        //show message on screen
      } else {
        //if marked no connection then reneter room
        Navigator.pop(widget.dialogPleaseWaitContext);
        widget.dialogPleaseWaitContext = null;
        FlutterLogs.logInfo("Dashboard", "ConnectivityResult", "connection");
        if (widget.hadNoConnection) {
          FlutterLogs.logInfo(
              "Dashboard", "ConnectivityResult", "reconnecting - exit room");
          if (_mqttClient != null) {
            _mqttClient.disconnect();
          }
          FlutterLogs.logInfo(
              "Dashboard", "ConnectivityResult", "reconnecting - enter room");
          //enter room
          setState(() {
            stream.exit();
            videoRoom.exitRoom();
            _mqttClient.disconnect();
            //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
            Navigator.of(widget.state.context).pop(false);
            widget.callReneter();
          });
          widget.hadNoConnection = false;
        }
      }
      //exit room
      //reneter with the same room number
    });

    streamSubscription =
        phoneStateCallEvent.listen((PhoneStateCallEvent event) {
      print('Call is Incoming or Connected' + event.stateC);
      //event.stateC has values "true" or "false"
      //if had a ring or connected need to re-enter
      if (event.stateC == true) {
        //mark re-enter
        FlutterLogs.logInfo("Dashboard", "phoneCall", "mark re-enter");
        callInProgress = true;
      } else if (callInProgress) {
        callInProgress = false;
        FlutterLogs.logInfo(
            "Dashboard", "phoneCall", "reconnecting - enter room");
        //enter room
        setState(() {
          stream.exit();
          videoRoom.exitRoom();
          _mqttClient.disconnect();
          //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
          Navigator.of(widget.state.context).pop(false);
          widget.callReneter();
        });
      }
    });
    videoRoom.RoomReady = () {
      final authService = context.read<AuthService>();
      if (_mqttClient == null) {
        _mqttClient = MQTTClient(
            authService.getUserEmail(),
            authService.getToken().accessToken,
            this.handleCmdData,
            this.connectedToBroker,
            this.subscribedToTopic);
        _mqttClient.connect();
      }
    };
    videoRoom.callExitRoomUserExists = () {
      stream.exit();
      videoRoom.exitRoom();
      if (_mqttClient != null)
        _mqttClient.unsubscribe("galaxy/room/" + _activeRoomId);
      showDialog(
        context: context,
        builder: (context) => new AlertDialog(
          title: new Text('Room Message'),
          content: Text('Your user is already in the room'),
          actions: <Widget>[
            new FlatButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();

                Navigator.of(widget.state.context).pop();

                // dismisses only the dialog and returns nothing
              },
              child: new Text('OK'),
            ),
          ],
        ),
      );
    };
    activeUser = context.read<MainStore>().activeUser;

    widget.audioMute = true;
    widget.videoMute = true;

    videoRoom.updateVideoState = (mute) {
      FlutterLogs.logInfo("Dashboard", "updateVideoState", "value $mute");
      setState(() {
        widget.videoMute = mute;
      });
    };

    initAudioMgr();
  }

  Future<void> initAudioMgr() async {
    FlutterAudioManager.setListener(() async {
      FlutterLogs.logInfo(
          "VideoRoom", "FlutterAudioManager", "######## audio device changed");
      await getAudioInput();

      setState(() {});
    });

    await getAudioInput();
    if (!mounted) return;
    setState(() {});
  }

  getAudioInput() async {
    _currentInput = await FlutterAudioManager.getCurrentOutput();
    if (_currentInput.port == AudioPort.receiver) {
      widget._audioDevice = AudioDevice.receiver;
    } else if (_currentInput.port == AudioPort.speaker) {
      widget._audioDevice = AudioDevice.speaker;
    } else if (_currentInput.port == AudioPort.bluetooth) {
      widget._audioDevice = AudioDevice.bluetooth;
    }
    FlutterLogs.logInfo("VideoRoom", "getAudioInput",
        "######## current audio device: $_currentInput");
    _availableInputs = await FlutterAudioManager.getAvailableInputs();
    FlutterLogs.logInfo("VideoRoom", "getAudioInput",
        "######## available audio devices: $_availableInputs");
  }

  void handleCmdData(String msgPayload) {
    FlutterLogs.logInfo(
        "Dashboard", "handleCmdData", "Received message: $msgPayload");
    try {
      var jsonCmd = JsonDecoder().convert(msgPayload);
      switch (jsonCmd["type"]) {
        case "client-state":
          videoRoom.setUserState(jsonCmd["user"]);
          break;
      }
    } on FormatException catch (e) {
      FlutterLogs.logError("Dashboard", "handleCmdData",
          "The provided string is not valid JSON: ${e.toString()}");
    }
  }

  void connectedToBroker() {
    _mqttClient.subscribe("galaxy/room/" + _activeRoomId);
    // updateRoomWithMyVideoState();
  }

  void subscribedToTopic(String topic) {
    if (topic == "galaxy/room/" + _activeRoomId) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        updateRoomWithMyVideoState();
      });
    }
  }

  void updateRoomWithMyVideoState() {
    FlutterLogs.logInfo("Dashboard", "updateRoomWithMyVideoState",
        "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@");
    var userData = activeUser.toJson();
    userData["camera"] = !widget.videoMute;
    userData["question"] = false;
    userData["rfid"] = videoRoom.getMyFeedId();
    var message = {};
    message["type"] = "client-state";
    message["user"] = userData;
    JsonEncoder encoder = JsonEncoder();
    _mqttClient.send("galaxy/room/" + _activeRoomId, encoder.convert(message));
  }

  Icon setIcon() {
    if (widget._audioDevice == AudioDevice.receiver) {
      return Icon(Icons.phone);
    } else if (widget._audioDevice == AudioDevice.speaker) {
      return Icon(Icons.volume_up);
    } else if (widget._audioDevice == AudioDevice.bluetooth) {
      return Icon(Icons.bluetooth);
    } else {
      return Icon(Icons.do_not_disturb);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRoom = context.select((MainStore s) => s.activeRoom);
    _activeRoomId = activeRoom.room.toString();

    return WillPopScope(
      onWillPop: () {
        Navigator.of(context).pop(true);
        stream.exit();
        videoRoom.exitRoom();
        _mqttClient.unsubscribe("galaxy/room/" + _activeRoomId);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ]);
        return;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(activeRoom.description), actions: <Widget>[
          Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                  onTap: () async {
                    bool res = false;
                    if (_currentInput.port == AudioPort.receiver) {
                      res = await FlutterAudioManager.changeToSpeaker();
                      print(">>>>>>>>> change to speaker: $res");
                    } else if (_currentInput.port == AudioPort.speaker) {
                      res = await FlutterAudioManager.changeToBluetooth();
                      print(">>>>>>>>> change to receiver: $res");
                    } else {
                      res = await FlutterAudioManager.changeToReceiver();
                      print(">>>>>>>>> change to receiver: $res");
                    }
                    setState(() {
                      getAudioInput();
                    });
                  },
                  child: setIcon()))
        ]),
        body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [stream, videoRoom]),
        bottomNavigationBar: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                label: "Mic",
                icon: widget.audioMute
                    ? Icon(Icons.mic_off, color: Colors.red)
                    : Icon(Icons.mic, color: Colors.white)),

            BottomNavigationBarItem(
                label: "Video",
                icon: widget.videoMute
                    ? Icon(Icons.videocam_off, color: Colors.red)
                    : Icon(Icons.videocam)),

            // todo: uncomment upon Q logic implemented
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.live_help),
            //   label: 'Ask Question',
            // )
            // todo <<<
          ],
          onTap: (value) {
            FlutterLogs.logInfo("Dashboard", "onTap", value.toString());
            switch (value) {
              case 0:
                videoRoom.mute();
                setState(() {
                  widget.audioMute = !widget.audioMute;
                });

                break;
              case 1:
                videoRoom.toggleVideo();
                setState(() {
                  widget.videoMute = !widget.videoMute;
                  updateRoomWithMyVideoState();
                });
                break;
            }
          },
        ),
      ),
    );
  }
}
