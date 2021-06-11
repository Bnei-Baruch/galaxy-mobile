import 'dart:async';
import 'dart:convert';

import 'package:connectivity/connectivity.dart';
import 'package:provider/provider.dart';
import 'package:phone_state_i/phone_state_i.dart';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_audio_manager/flutter_audio_manager.dart';

import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/screens/streaming/streaming.dart';
import 'package:galaxy_mobile/screens/video_room/videoRoomWidget.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:galaxy_mobile/widgets/loading_indicator.dart';
import 'package:galaxy_mobile/widgets/videoRoomDrawer.dart';
import 'package:galaxy_mobile/services/authService.dart';

enum AudioDevice { receiver, speaker, bluetooth }

class Dashboard extends StatefulWidget {
  bool audioMute = true;
  bool videoMute = true;
  // bool isQuestion = false;
  bool hadNoConnection = false;
  bool audioMode = false;

  _DashboardState state;
  AudioDevice _audioDevice = AudioDevice.receiver;
  MQTTClient _mqttClient;
  BuildContext dialogPleaseWaitContext;
  VoidCallback callReEnter;

  MQTTClient getMQTTClient() {
    return _mqttClient;
  }

  var stream = StreamingUnified();
  var videoRoom = VideoRoom();

  Map<String, dynamic> userMap;

  Timer userTimer;

  @override
  State createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  var activeUser;
  bool callInProgress;
  String _activeRoomId;

  StreamSubscription<ConnectivityResult> subscription;
  StreamSubscription streamSubscription;

  int formFlex;

  int mapFlex;

  @override
  void initState() {
    // TODO: implement initState
    FlutterAudioManager.setListener(() {
      FlutterLogs.logInfo("dashboard", "onInputChanged", "");
    });

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
                          text: "No Internet... reconnecting")));
            });
        Future.delayed(const Duration(seconds: 30), () {
          if (widget.dialogPleaseWaitContext != null) {
            widget.stream.exit();
            widget.videoRoom.exitRoom();
            widget.userTimer.cancel();
            if (widget._mqttClient != null) widget._mqttClient.disconnect();
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
          if (widget._mqttClient != null) {
            widget._mqttClient.disconnect();
          }
          FlutterLogs.logInfo(
              "Dashboard", "ConnectivityResult", "reconnecting - enter room");
          //enter room
          setState(() {
            widget.stream.exit();
            widget.videoRoom.exitRoom();
            widget._mqttClient.disconnect();
            widget.userTimer.cancel();
            //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
            Navigator.of(widget.state.context).pop(false);
            widget.callReEnter();
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
          widget.stream.exit();
          widget.videoRoom.exitRoom();
          widget._mqttClient.disconnect();
          widget.userTimer.cancel();

          //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
          Navigator.of(widget.state.context).pop(false);
          widget.callReEnter();
        });
      }
    });
    widget.videoRoom.RoomReady = () {
      final authService = context.read<AuthService>();
      if (widget._mqttClient == null) {
        widget._mqttClient = MQTTClient(
            authService.getUserEmail(),
            authService.getToken().accessToken,
            this.handleCmdData,
            this.connectedToBroker,
            this.subscribedToTopic);
        widget._mqttClient.connect();
      }
    };
    widget.videoRoom.callExitRoomUserExists = () {
      widget.stream.exit();
      widget.videoRoom.exitRoom();
      widget.userTimer.cancel();
      if (widget._mqttClient != null)
        widget._mqttClient.unsubscribe("galaxy/room/" + _activeRoomId);
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
    widget.videoRoom.updateGlxUserCB = (user) {
      widget.userMap = user;
      updateGxyUser(context, user);
    };
    activeUser = context.read<MainStore>().activeUser;

    widget.audioMute = true;
    widget.videoMute = true;

    widget.videoRoom.updateVideoState = (mute) {
      FlutterLogs.logInfo("Dashboard", "updateVideoState", "value $mute");
      setState(() {
        widget.videoMute = mute;
      });
    };

    initAudioMgr();

    widget.userTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      FlutterLogs.logInfo(
          "Dashboard", "updateUser step 1", "tick ${timer.tick}");
      if (timer.tick != 10) {
        updateGxyUser(context, widget.userMap);
      } else {
        timer.cancel();
        widget.userTimer = Timer.periodic(Duration(seconds: 30), (timer) {
          FlutterLogs.logInfo(
              "Dashboard", "updateUser step 2", "tick ${timer.tick}");

          updateGxyUser(context, widget.userMap);
        });
      }
    });
  }

  Future<void> initAudioMgr() async {
    FlutterAudioManager.setListener(() async {
      FlutterLogs.logInfo(
          "VideoRoom", "FlutterAudioManager", "######## audio device changed");

      //await getAudioInput();

      setState(() {});
    });

    if (changeAudioDevice(AudioDevice.receiver)) {
      FlutterLogs.logInfo(
          "dashboard", "initAudioMgr", ">>> switch to RECEIVER: Success");
      widget._audioDevice = AudioDevice.receiver;
    } else {
      FlutterLogs.logError(
          "dashboard", "initAudioMgr", ">>> switch to RECEIVER: Failed");
    }

    // await getAudioInput();
    if (!mounted) return;
    setState(() {});
  }

  switchAudioDevice() async {
    FlutterLogs.logInfo(
        "dashboard", "switchAudioDevice", "#### switchAudioDevice BEGIN");
    bool res;
    if (widget._audioDevice == AudioDevice.receiver) {
      res = await changeAudioDevice(AudioDevice.speaker);
      if (res) {
        FlutterLogs.logInfo(
            "dashboard", "switchAudioDevice", ">>> switch to SPEAKER: Success");
        widget._audioDevice = AudioDevice.speaker;
      } else {
        FlutterLogs.logError(
            "dashboard", "switchAudioDevice", ">>> switch to SPEAKER: Failed");
      }
    } else if (widget._audioDevice == AudioDevice.speaker) {
      res = await changeAudioDevice(AudioDevice.bluetooth);
      if (res) {
        FlutterLogs.logInfo("dashboard", "switchAudioDevice",
            ">>> switch to BLUETOOTH: Success");
        widget._audioDevice = AudioDevice.bluetooth;
      } else {
        FlutterLogs.logError("dashboard", "switchAudioDevice",
            ">>> switch to BLUETOOTH: Failed");
      }
    } else if (widget._audioDevice == AudioDevice.bluetooth) {
      res = await changeAudioDevice(AudioDevice.receiver);
      if (res) {
        FlutterLogs.logInfo("dashboard", "switchAudioDevice",
            ">>> switch to RECEIVER: Success");
        widget._audioDevice = AudioDevice.receiver;
      } else {
        FlutterLogs.logError(
            "dashboard", "switchAudioDevice", ">>> switch to RECEIVER: Failed");
      }
    }
    FlutterLogs.logInfo(
        "dashboard", "switchAudioDevice", "#### switchAudioDevice END");
  }

  changeAudioDevice(AudioDevice audioDevice) async {
    bool res = false;
    switch (audioDevice) {
      case AudioDevice.receiver:
        res = await FlutterAudioManager.changeToReceiver();
        break;
      case AudioDevice.speaker:
        res = await FlutterAudioManager.changeToSpeaker();
        break;
      case AudioDevice.bluetooth:
        res = await FlutterAudioManager.changeToBluetooth();
        break;
      default:
        FlutterLogs.logError("dashboard", "changeAudioDevice",
            "invalid audio device: ${audioDevice.toString()}");
    }
    return res;
  }

  // getAudioInput() async {
  //   _currentInput = await FlutterAudioManager.getCurrentOutput();
  //   if (_currentInput.port == AudioPort.receiver) {
  //     widget._audioDevice = AudioDevice.receiver;
  //   } else if (_currentInput.port == AudioPort.speaker) {
  //     widget._audioDevice = AudioDevice.speaker;
  //   } else if (_currentInput.port == AudioPort.bluetooth) {
  //     widget._audioDevice = AudioDevice.bluetooth;
  //   }
  //   FlutterLogs.logInfo("VideoRoom", "getAudioInput",
  //       "######## current audio device: $_currentInput");
  //   // _availableInputs = await FlutterAudioManager.getAvailableInputs();
  //   // FlutterLogs.logInfo("VideoRoom", "getAudioInput",
  //   //     "######## available audio devices: $_availableInputs");
  // }

  void handleCmdData(String msgPayload) {
    FlutterLogs.logInfo(
        "Dashboard", "handleCmdData", "Received message: $msgPayload");
    try {
      var jsonCmd = JsonDecoder().convert(msgPayload);
      switch (jsonCmd["type"]) {
        case "client-state":
          widget.videoRoom.setUserState(jsonCmd["user"]);
          break;

        case "audio-out":
          if (widget.videoRoom.getIsQuestion()) {
            widget.videoRoom.toggleQuestion();
            updateRoomWithMyState(false);
          }
          widget.stream.toggleOnAir(jsonCmd);
          break;
      }
    } on FormatException catch (e) {
      FlutterLogs.logError("Dashboard", "handleCmdData",
          "The provided string is not valid JSON: ${e.toString()}");
    }
  }

  void connectedToBroker() {
    widget._mqttClient.subscribe("galaxy/room/" + _activeRoomId);
    // updateRoomWithMyVideoState();
  }

  void subscribedToTopic(String topic) {
    if (topic == "galaxy/room/" + _activeRoomId) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        updateRoomWithMyState(false);
      });
    }
  }

  void updateRoomWithMyState(bool isQuestion) {
    var userData;
    if (widget.userMap != null)
      userData = widget.userMap;
    else
      userData = activeUser.toJson();

    userData["camera"] = !widget.videoMute;
    userData["question"] = isQuestion;
    userData["rfid"] = widget.videoRoom.getMyFeedId();
    var message = {};
    message["type"] = "client-state";
    message["user"] = userData;
    widget._mqttClient
        .send("galaxy/room/" + _activeRoomId, JsonEncoder().convert(message));
  }

  Icon setIcon() {
    FlutterLogs.logInfo("dashboard", "setIcon", "#### setIcon BEGIN");
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

    return
        // WillPopScope(
        // onWillPop: () {
        //   Navigator.of(context).pop(true);
        //   stream.exit();
        //   videoRoom.exitRoom();
        //   widget._mqttClient.unsubscribe("galaxy/room/" + _activeRoomId);
        //   SystemChrome.setPreferredOrientations([
        //     DeviceOrientation.portraitUp,
        //     DeviceOrientation.portraitDown,
        //     DeviceOrientation.landscapeLeft,
        //     DeviceOrientation.landscapeRight
        //   ]);
        //   return;
        // },
        // child:
        Scaffold(
      appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop(true);
              widget.stream.exit();
              widget.videoRoom.exitRoom();
              widget.userTimer.cancel();
              widget._mqttClient.unsubscribe("galaxy/room/" + _activeRoomId);
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight
              ]);
              return;
            },
          ),
          title: Text(activeRoom.description),
          actions: <Widget>[
            IconButton(
                icon: setIcon(),
                onPressed: () async {
                  await switchAudioDevice();
                  setState(() {});
                }),

            // Padding(
            //     padding: EdgeInsets.only(right: 20.0),
            //     child: GestureDetector(
            //         onTap: () async {
            //           switchAudioDevice();
            //           // setState(() {
            //           //   getAudioInput();
            //           // });
            //         },
            //         child: setIcon()))
          ]),
      drawer: VideoRoomDrawer(),
      body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [widget.stream, widget.videoRoom]),
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
          BottomNavigationBarItem(
              label: 'Ask Question',
              icon: widget.videoRoom.getIsQuestion()
                  ? Icon(Icons.live_help, color: Colors.red)
                  : Icon(Icons.live_help)),
          BottomNavigationBarItem(
              label: "Audio Mode",
              icon: widget.audioMode
                  ? Icon(Icons.supervised_user_circle_outlined,
                      color: Colors.red)
                  : Icon(Icons.supervised_user_circle_outlined)),
        ],
        onTap: (value) {
          FlutterLogs.logInfo("Dashboard", "onTap", value.toString());
          switch (value) {
            case 0:
              widget.videoRoom.mute();
              setState(() {
                widget.audioMute = !widget.audioMute;
              });

              break;
            case 1:
              widget.videoRoom.toggleVideo();
              setState(() {
                widget.videoMute = !widget.videoMute;
                updateRoomWithMyState(false);
              });
              break;
            case 2:
              if (widget.videoRoom.questionInRoom == null) {
                bool isQ = widget.videoRoom.getIsQuestion();
                widget.videoRoom.toggleQuestion();
                updateRoomWithMyState(!isQ);
                setState(() {
                  widget.videoRoom.setIsQuestion(!isQ);
                });
              } else {
                FlutterLogs.logWarn("Dashboard", "toggleQuestion",
                    "question already set in room");
              }
              break;
            case 3:
              setState(() {
                widget.audioMode = !widget.audioMode;
                widget.stream.toggleAudioMode();
              });
              widget.videoRoom.toggleAudioMode();
              break;
          }
        },
      ),
    );
    // );
  }
}

void updateGxyUser(context, userData) async {
  var user_data = await Utils.parseJson("user_update.json");
  Provider.of<MainStore>(context, listen: false).updaterUser(userData);
}
