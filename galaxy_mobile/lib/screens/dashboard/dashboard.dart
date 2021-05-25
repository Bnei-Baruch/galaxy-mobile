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
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../services/authService.dart';

enum AudioDevice { receiver, speaker, bluetooth }

class Dashboard extends StatefulWidget {
  bool audioMute = true;
  bool videoMute = true;
  AudioDevice _audioDevice = AudioDevice.receiver;

  _DashboardState state;

  bool hadNoConnection = false;

  @override
  State createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  var stream = StreamingUnified();
  var videoRoom = VideoRoom();
  var activeUser;

  MQTTClient _mqttClient;

  String _activeRoomId;

  StreamSubscription<ConnectivityResult> subscription;

  @override
  void initState() {
    // TODO: implement initState
    FlutterAudioManager.setListener(() {
      FlutterLogs.logInfo("dashboard", "onInputChanged", "!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    });

    widget.state = this;
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
        //show message on screen
      } else {
        //if marked no connection then reneter room
        FlutterLogs.logInfo("Dashboard", "ConnectivityResult", "connection");
        if (widget.hadNoConnection) {
          FlutterLogs.logInfo(
              "Dashboard", "ConnectivityResult", "reconnecting - exit room");
          // stream.exit();
          videoRoom.exitRoom();
          if (_mqttClient != null) {
            _mqttClient.disconnect();
          }
          FlutterLogs.logInfo(
              "Dashboard", "ConnectivityResult", "reconnecting - enter room");
          //enter room
          setState(() {
            final authService = context.read<AuthService>();

            // stream = StreamingUnified();
            // videoRoom = VideoRoom();
            stream.reconnect();
            _mqttClient = MQTTClient(
                authService.getUserEmail(),
                authService.getAuthToken(),
                this.handleCmdData,
                this.connectedToBroker,
                this.subscribedToTopic);
            _mqttClient.connect();
          });
          widget.hadNoConnection = false;
        }
      }
      //exit room
      //reneter with the same room number
    });

    videoRoom.RoomReady = () {
      final authService = context.read<AuthService>();
      if (_mqttClient == null) {
        _mqttClient = MQTTClient(
            authService.getUserEmail(),
            authService.getAuthToken(),
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

      //await getAudioInput();

      setState(() {});
    });

    if (changeAudioDevice(AudioDevice.receiver)) {
      FlutterLogs.logInfo("dashboard", "initAudioMgr",
          ">>> switch to RECEIVER: Success");
      widget._audioDevice = AudioDevice.receiver;
    } else {
      FlutterLogs.logError("dashboard", "initAudioMgr",
          ">>> switch to RECEIVER: Failed");
    }

    // await getAudioInput();
    if (!mounted) return;
    setState(() {});
  }

  switchAudioDevice() async {
    FlutterLogs.logInfo("dashboard", "switchAudioDevice", "#### switchAudioDevice BEGIN");
    bool res;
    if (widget._audioDevice == AudioDevice.receiver) {
      res = await changeAudioDevice(AudioDevice.speaker);
      if (res) {
        FlutterLogs.logInfo("dashboard", "switchAudioDevice",
            ">>> switch to SPEAKER: Success");
        widget._audioDevice = AudioDevice.speaker;
      } else {
        FlutterLogs.logError("dashboard", "switchAudioDevice",
            ">>> switch to SPEAKER: Failed");
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
        FlutterLogs.logError("dashboard", "switchAudioDevice",
            ">>> switch to RECEIVER: Failed");
      }
    }
    FlutterLogs.logInfo("dashboard", "switchAudioDevice", "#### switchAudioDevice END");
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
          IconButton(
            icon: setIcon(),
            onPressed: () async {
              await switchAudioDevice();
              setState(() {});
              },
          )
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

//         drawer: Drawer(
//   // Add a List View to the drawer. This ensures the user can scroll
//   // through the options in the drawer if there isn't enough vertical
//   // space to fit everything.
//   child: ListView(
//     // Important: Remove any padding from the ListView.
//     padding: EdgeInsets.zero,
//     children: <Widget>[
//       DrawerHeader(
//         child: Text('Drawer Header'),
//         decoration: BoxDecoration(
//           color: Colors.blue,
//         ),
//       ),
//       ListTile(
//         leading: Icon(Icons.home),
//         title: Text('My Account'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//       ListTile(
//         title: Text('Settings'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//       ListTile(
//         title: Text('Sign out'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//       Divider(),
//       ListTile(
//         title: Text('Feedback'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//       ListTile(
//         title: Text('Help'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//     ],
//   ),
// ),
