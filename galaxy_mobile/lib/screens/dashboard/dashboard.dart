import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:mdi/mdi.dart';
import 'package:provider/provider.dart';
import 'package:phone_state_i/phone_state_i.dart';

import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_audio_manager/flutter_audio_manager.dart';

import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/screens/streaming/streaming.dart';
import 'package:galaxy_mobile/screens/video_room/videoRoomWidget.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:galaxy_mobile/widgets/loading_indicator.dart';
import 'package:galaxy_mobile/chat/chatMessage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum AudioDevice { receiver, speaker, bluetooth }

final int TIME_TO_SHOW_CONTROLS = 10;

class Dashboard extends StatefulWidget {
  @override
  State createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  StreamingUnified stream = StreamingUnified();
  VideoRoom videoRoom = VideoRoom();
  // var chat = Chat();
  var activeUser;
  bool callInProgress;
  String _activeRoomId;
  AudioDevice _audioDevice = AudioDevice.speaker;

  BuildContext dialogPleaseWaitContext;
  VoidCallback callReEnter;

  bool audioMute = true;
  bool videoMute = true;
  bool hadNoConnection = false;
  bool audioMode = false;
  bool questionDisabled = false;
  bool isFullScreen = false;

  Map<String, dynamic> userMap;
  Timer userTimer;
  int formFlex;
  int mapFlex;

  StreamSubscription<ConnectivityResult> subscription;
  StreamSubscription streamSubscription;

  bool _show = false;

  int pagePosition = 0;

  int feedsLength = 1;

  AnimationController controller;
  Animation<Offset> offset;

  var  activeRoom;

  @override
  void initState() {
    // TODO: implement initState
    FlutterAudioManager.setListener(() {
      FlutterLogs.logInfo("dashboard", "onInputChanged", "");
    });

    controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 300));

    offset = Tween<Offset>(begin: Offset.zero, end: Offset(0.0, 1.0))
        .animate(controller);

     activeRoom = context.read<MainStore>().activeRoom;
    _activeRoomId = activeRoom.room.toString();


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

        hadNoConnection = true;
        showDialog(
            context: context,
            useRootNavigator: false,
            barrierDismissible: false,
            builder: (BuildContext context) {
              dialogPleaseWaitContext = context;
              return WillPopScope(
                  onWillPop: () {
                    Navigator.of(dialogPleaseWaitContext).pop();
                    return Future.value(true);
                  },
                  child: Dialog(
                      backgroundColor: Colors.transparent,
                      child: LoadingIndicator(
                          text: "No Internet... reconnecting")));
            });
        Future.delayed(const Duration(seconds: 30), () {
          if (dialogPleaseWaitContext != null) {
            stream.exit();
            videoRoom.exitRoom();
            userTimer.cancel();

            Navigator.pop(dialogPleaseWaitContext);
            Navigator.of(context).pop();
          }
        });
        //show message on screen
      } else {
        //if marked no connection then reneter room
        Navigator.pop(dialogPleaseWaitContext);
        dialogPleaseWaitContext = null;
        FlutterLogs.logInfo("Dashboard", "ConnectivityResult", "connection");
        if (hadNoConnection) {
          FlutterLogs.logInfo(
              "Dashboard", "ConnectivityResult", "reconnecting - exit room");

          FlutterLogs.logInfo(
              "Dashboard", "ConnectivityResult", "reconnecting - enter room");
          //enter room
          setState(() {
            stream.exit();
            videoRoom.exitRoom();

            userTimer.cancel();
            //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
            Navigator.of(this.context).pop(false);
            callReEnter();
          });
          hadNoConnection = false;
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
      if (event.stateC == "true") {
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
          // if (mqttClient != null) {
          //   mqttClient.disconnect();
          // }
          userTimer.cancel();

          //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
          Navigator.of(this.context).pop(false);
          callReEnter();
        });
      }
    });

    videoRoom.updateDots = (int position, int length) {
      if (mounted) {
        setState(() {
          pagePosition = position;
          feedsLength = length;
        });
      }
    };
    videoRoom.RoomReady = () {
      FlutterLogs.logInfo("Dashboard", "videoRoom", "RoomReady");
      initMQTT();
      initAudioMgr();
      tapped();
    };
    videoRoom.updateGoingToBackground = (){
      updateRoomWithMyState(false);
    };
    videoRoom.callExitRoomUserExists = () {
      stream.exit();
      videoRoom.exitRoom();
      userTimer.cancel();

      showDialog(
        context: context,
        builder: (context) => new AlertDialog(
          title: new Text('Room Message'),
          content: Text('Your user is already in the room'),
          actions: <Widget>[
            new FlatButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.of(this.context).pop();
                // dismisses only the dialog and returns nothing
              },
              child: new Text('OK'),
            ),
          ],
        ),
      );
    };
    videoRoom.updateGlxUserCB = (user) {
      userMap = user;
      updateGxyUser(context, user);
    };
    activeUser = context.read<MainStore>().activeUser;
    _audioDevice = AudioDevice.values[(context.read<MainStore>().audioDevice)];

    audioMute = true;
    videoMute = true;

    videoRoom.updateVideoState = (mute) {
      FlutterLogs.logInfo("Dashboard", "updateVideoState", "value $mute");
      setState(() {
        videoMute = mute;
      });
    };



    userTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      FlutterLogs.logInfo(
          "Dashboard", "updateUser step 1", "tick ${timer.tick}");
      if (timer.tick != 10) {
        updateGxyUser(context, userMap);
      } else {
        timer.cancel();
        userTimer = Timer.periodic(Duration(seconds: 30), (timer) {
          FlutterLogs.logInfo(
              "Dashboard", "updateUser step 2", "tick ${timer.tick}");

          updateGxyUser(context, userMap);
        });
      }
    });

    stream.fullscreen = (fullscreen) {
      isFullScreen = fullscreen;
      videoRoom.setFullScreen(fullscreen);
      setState(() {});
    };
  }

  Future<void> initAudioMgr() async {
    FlutterAudioManager.setListener(() async {
      FlutterLogs.logInfo(
          "VideoRoom", "FlutterAudioManager", "######## audio device changed");

      //await getAudioInput();

      setState(() {});
    });


    if (await changeAudioDevice(_audioDevice)) {
      FlutterLogs.logInfo(
          "dashboard", "initAudioMgr", ">>> switch to ${_audioDevice.toString()}: Success");

    } else {
      FlutterLogs.logError(
          "dashboard", "initAudioMgr", ">>> switch to SPEAKER: Failed");
    }

    if (!mounted) return;
    setState(() {});
  }

  switchAudioDevice() async {
    FlutterLogs.logInfo(
        "dashboard", "switchAudioDevice", "#### switchAudioDevice BEGIN");
    bool res;
    _audioDevice = AudioDevice.values[(context.read<MainStore>().audioDevice)];
    if (_audioDevice == AudioDevice.receiver) {
      res = await changeAudioDevice(AudioDevice.speaker);
      if (res) {
        FlutterLogs.logInfo(
            "dashboard", "switchAudioDevice", ">>> switch to SPEAKER: Success");
        context
            .read<MainStore>()
            .setAudioDevice(AudioDevice.speaker.index);
      } else {
        FlutterLogs.logError(
            "dashboard", "switchAudioDevice", ">>> switch to SPEAKER: Failed");
      }
    } else if (_audioDevice == AudioDevice.speaker) {
      res = await changeAudioDevice(AudioDevice.bluetooth);
      AudioInput currentOutput = await FlutterAudioManager.getCurrentOutput();
      if (res && currentOutput.port == AudioPort.bluetooth) {
        FlutterLogs.logInfo("dashboard", "switchAudioDevice",
            ">>> switch to BLUETOOTH: Success");
        context
            .read<MainStore>()
            .setAudioDevice(AudioDevice.bluetooth.index);
      } else {
        FlutterLogs.logError("dashboard", "switchAudioDevice",
            ">>> switch to BLUETOOTH: Failed");
        res = await changeAudioDevice(AudioDevice.receiver);
        if (res) {
          FlutterLogs.logInfo("dashboard", "switchAudioDevice",
              ">>> switch to RECEIVER: Success");
          context
              .read<MainStore>()
              .setAudioDevice(AudioDevice.receiver.index);
        } else {
          FlutterLogs.logError("dashboard", "switchAudioDevice",
              ">>> switch to RECEIVER: Failed");
        }
      }

    } else if (_audioDevice == AudioDevice.bluetooth) {
      res = await changeAudioDevice(AudioDevice.receiver);
      if (res) {
        FlutterLogs.logInfo("dashboard", "switchAudioDevice",
            ">>> switch to RECEIVER: Success");
        context
            .read<MainStore>()
            .setAudioDevice(AudioDevice.receiver.index);
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



  void handleCmdData(String msgPayload) {
    FlutterLogs.logInfo(
        "Dashboard", "handleCmdData", "received message: $msgPayload");
    try {
      var jsonCmd = JsonDecoder().convert(msgPayload);
      if (jsonCmd["textroom"] != null) {
        String textElem = jsonCmd["text"];
        var chatCmd = JsonDecoder().convert(textElem);
        String msgText = chatCmd["text"];
        context.read<MainStore>().addChatMessage(
            ChatMessage(chatCmd["user"]["display"], msgText, "message"));
      } else {
        switch (jsonCmd["type"]) {
          case "client-state":
            videoRoom.setUserState(jsonCmd["user"]);
            setState(() {
              //disable question at bottom in case other friends ask question
              if (jsonCmd["user"]["id"] != userMap["id"]) {
                questionDisabled = jsonCmd["user"]["question"];
              }
            });
            break;
          case "audio-out":
            if (videoRoom.getIsQuestion()) {
              videoRoom.toggleQuestion();
              updateRoomWithMyState(false);
            }
            stream.toggleOnAir(jsonCmd);
            break;
        }
      }
    } on FormatException catch (e) {
      FlutterLogs.logError("Dashboard", "handleCmdData",
          "The provided string is not valid JSON: ${e.toString()}");
    }
  }

  void handleConnectionFailed() {
    stream.exit();
    videoRoom.exitRoom();
    userTimer.cancel();
    showDialog(
      context: context,
      builder: (context) => new AlertDialog(
        title: new Text('Room Message'),
        content: Text('Connection to server failure'),
        actions: <Widget>[
          new FlatButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(this.context).pop();
              // dismisses only the dialog and returns nothing
            },
            child: new Text('OK'),
          ),
        ],
      ),
    );
  }

  void handleOnDisconnection() {
    //reconnect
    FlutterLogs.logInfo(
        "Dashboard", "mqqt","handleOnDisconnection");


  }

  void connectedToBroker() {
    final mqttClient = context.read<MQTTClient>();
    mqttClient.subscribe("galaxy/room/" + _activeRoomId);
  }

  void subscribedToTopic(String topic) {
    if (topic == "galaxy/room/" + _activeRoomId) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        updateRoomWithMyState(false);

        //toggle audio mode only
        final s = context.read<MainStore>();
        audioMode = s.audioMode;
        FlutterLogs.logInfo(
            "Dashboard", "videoRoom", "audioMode toggle $audioMode");

        if (audioMode) {
          // stream.toggleAudioMode();
          videoRoom.toggleAudioMode();
        }
      });
    }
  }

  void updateRoomWithMyState(bool isQuestion) {
    final mqttClient = context.read<MQTTClient>();
    var userData;
    if (userMap != null)
      userData = userMap;
    else
      userData = activeUser.toJson();

    userData["camera"] = !videoMute;
    userData["question"] = isQuestion;
    userData["rfid"] = videoRoom.getMyFeedId();
    var message = {};
    message["type"] = "client-state";
    message["user"] = userData;
    FlutterLogs.logInfo("dashboard", "updateRoomWithMyState", "${mqttClient.getStatus()}");
    mqttClient.send(
        "galaxy/room/" + _activeRoomId, JsonEncoder().convert(message));
    userMap = userData;
  }

  Icon setIcon() {
    FlutterLogs.logInfo("dashboard", "setIcon", "#### setIcon BEGIN");
    _audioDevice = AudioDevice.values[(context.read<MainStore>().audioDevice)];
    if (_audioDevice == AudioDevice.receiver) {
      return Icon(Mdi.volumeMute);
    } else if (_audioDevice == AudioDevice.speaker) {
      return Icon(Icons.volume_up);
    } else if (_audioDevice == AudioDevice.bluetooth) {
      return Icon(Icons.bluetooth);
    } else {
      return Icon(Icons.do_not_disturb);
    }
  }


  @override
  Widget build(BuildContext context) {

    return WillPopScope(
        onWillPop: () {
          final mqttClient = context.read<MQTTClient>();
          Navigator.of(context).pop(true);
          stream.exit();
          videoRoom.exitRoom();
          userTimer.cancel();
          if (mqttClient != null) {
            mqttClient.unsubscribe("galaxy/room/$_activeRoomId");
            mqttClient.unsubscribe("galaxy/room/$_activeRoomId/chat");
            mqttClient.removeOnConnectedCallback();
            mqttClient.removeOnConnectionFailedCallback();
            mqttClient.removeOnMsgReceivedCallback();
            mqttClient.removeOnSubscribedCallback();
          }
          changeAudioDevice(AudioDevice.speaker);
          return;
        },
        child: Scaffold(
          appBar: isFullScreen
              ? null
              : !_show
                  ? CustomAppBar(
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        iconTheme: IconThemeData(color: Colors.transparent),
                        automaticallyImplyLeading: false,
                      ),
                      onTap: () => tapped(),
                    )
                  : AppBar(
                      backgroundColor: Colors.black26,
                      title: Text(activeRoom.description,
                          textAlign: TextAlign.center),
                      centerTitle: true,
                      leading: IconButton(
                          icon: setIcon(),
                          onPressed: () async {
                            await switchAudioDevice();
                            setState(() {});
                          }),
                      actions: <Widget>[
                          // IconButton(
                          //     icon: Icon(Icons.chat, color: Colors.white),
                          //     onPressed: () {
                          //       setState(() {
                          //         isChatVisible = !isChatVisible;
                          //       });
                          //     }),
                          Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextButton(
                                  style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStateProperty.all(
                                              Colors.white),
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                              Colors.red)),
                                  child: Text(
                                    'leave'.tr(),
                                  ),
                                  onPressed: () {
                                    final mqttClient =
                                        context.read<MQTTClient>();
                                    Navigator.of(context).pop(true);
                                    stream.exit();
                                    videoRoom.exitRoom();
                                    userTimer.cancel();
                                    if (mqttClient != null) {
                                      mqttClient.unsubscribe(
                                          "galaxy/room/$_activeRoomId");
                                      mqttClient.unsubscribe(
                                          "galaxy/room/$_activeRoomId/chat");
                                     // mqttClient.disconnect();
                                    }
                                  }))
                        ]),
          body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tapped(),
              child: OrientationBuilder(builder: (context, orientation) {
                return Stack(children: <Widget>[
                  Flex(
                      mainAxisAlignment: MainAxisAlignment.center,
                      direction: orientation == Orientation.landscape
                          ? Axis.horizontal
                          : Axis.vertical,
                      children: [
                        stream,
                        // GestureDetector(
                        //   child:
                        videoRoom,

                      ])
                ]);
              })),
          bottomNavigationBar: isFullScreen
              ? null
              : Stack(
                  children: [
                    GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => tapped(),
                        child: Container(
                          color: Colors.black,
                          height: kBottomNavigationBarHeight,
                          child: Align(
                            alignment: Alignment.center,
                            child: DotsIndicator(
                                dotsCount: (feedsLength / PAGE_SIZE).ceil() > 0
                                    ? (feedsLength / PAGE_SIZE).ceil()
                                    : 1,
                                position: pagePosition.toDouble()),
                          ),
                        )),
                    SlideTransition(
                      position: offset,
                      child: BottomNavigationBar(
                        showSelectedLabels: true, // <-- HERE
                        showUnselectedLabels: true,
                        selectedItemColor: Colors.white,
                        unselectedItemColor: Colors.white,
                        items: <BottomNavigationBarItem>[
                          BottomNavigationBarItem(
                              label: "mic".tr(),
                              icon: audioMute
                                  ? Icon(Icons.mic_off, color: Colors.red)
                                  : Icon(Icons.mic, color: Colors.white)),
                          BottomNavigationBarItem(
                              label: "camera".tr(),
                              icon: videoMute
                                  ? Icon(Icons.videocam_off, color: Colors.red)
                                  : Icon(Icons.videocam, color: Colors.white)),
                          BottomNavigationBarItem(
                              label: 'ask'.tr(),
                              icon: !questionDisabled
                                  ? (videoRoom.getIsQuestion()
                                      ? Icon(Mdi.help, color: Colors.red)
                                      : Icon(Mdi.help, color: Colors.white))
                                  : Icon(Mdi.help, color: Colors.grey)),
                          BottomNavigationBarItem(
                              label: "audio_mode".tr(),
                              icon: audioMode
                                  ? Icon(Mdi.accountVoice, color: Colors.red)
                                  : Icon(Mdi.accountVoice,
                                      color: Colors.white)),
                          BottomNavigationBarItem(
                              label: "more".tr(),
                              icon: audioMode
                                  ? Icon(Mdi.dotsVertical, color: Colors.red)
                                  : Icon(Mdi.dotsVertical,
                                      color: Colors.white)),
                        ],
                        onTap: (value) async {
                          FlutterLogs.logInfo(
                              "Dashboard", "onTap", value.toString());
                          switch (value) {
                            case 0:
                              videoRoom.mute();
                              setState(() {
                                audioMute = !audioMute;
                              });

                              break;
                            case 1:
                              videoRoom.toggleVideo();
                              setState(() {
                                videoMute = !videoMute;
                                updateRoomWithMyState(false);
                              });
                              break;
                            case 2:
                              if (videoRoom.questionInRoom == null) {
                                bool isQ = videoRoom.getIsQuestion();
                                videoRoom.toggleQuestion();
                                updateRoomWithMyState(!isQ);
                                setState(() {
                                  videoRoom.setIsQuestion(!isQ);
                                });
                              } else {
                                FlutterLogs.logWarn(
                                    "Dashboard",
                                    "toggleQuestion",
                                    "question already set in room");
                              }
                              break;
                            case 3:
                              setState(() {
                                audioMode = !audioMode;
                                stream.toggleAudioMode();
                              });
                              videoRoom.toggleAudioMode();
                              break;
                            case 4:
                              final position = buttonMenuPosition(context);
                              final result = await showMenu(
                                context: context,
                                position: position,
                                items: <PopupMenuItem<String>>[
                                  const PopupMenuItem<String>(
                                      child: ListTile(
                                          leading: Icon(Icons.how_to_vote),
                                          title: Text('vote')),
                                    value: "vote",
                                  ),
                                  const PopupMenuItem<String>(
                                      child: ListTile(
                          leading: Icon(Icons.mobile_friendly_sharp),
                          title: Text('friends')),
                                  value: "friends",),
                                ],


                              );
                              switch(result)
                              {
                                case "vote":
                                  print("user id ${activeUser.id}");
                                  showDialog(
                                      context: context,
                                      useRootNavigator: false,
                                      barrierDismissible: true,
                                      builder: (BuildContext context) {

                                        return WillPopScope(
                                            onWillPop: () {
                                              Navigator.of(context).pop();
                                              return Future.value(true);
                                            },
                                                  child:
                                                      Center(
                                                        child:

                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Container(
                                                        height: 50,
                                                  width: 50,
                                                  child:
                                                      WebView(
                                                        initialUrl: "https://vote.kli.one/button.html?answerId=1&userId=${activeUser.id}",
                                                        javascriptMode: JavascriptMode.unrestricted,

                                                      )
                                                      ),
                                                      Container(
                                                        height: 50,
                                                        width: 50,
                                                        child:
                                                      WebView(
                                                        initialUrl: "https://vote.kli.one/button.html?answerId=2&userId=${activeUser.id}",
                                                        javascriptMode: JavascriptMode.unrestricted,

                                                      ),
                                                      ),
                                                    ],
                                                  ),


                                                      ),

                                        );
                                      });
                                  break;
                              }
                             break;

    // <Button.Group>
    // <iframe
    // title={`${t("oldClient.vote")} 1`}
    // src={`https://vote.kli.one/button.html?answerId=1&userId=${user && user.id}`}
    // frameBorder="0"
    // />
    // <iframe
    // title={`${t("oldClient.vote")} 2`}
    // src={`https://vote.kli.one/button.html?answerId=2&userId=${user && user.id}`}
    // frameBorder="0"
    // />
    // </Button.Group>
                          }
                        },
                      ),
                    ),
                  ],
                ),
        ));
    // );

  }

  RelativeRect buttonMenuPosition(BuildContext c) {
    final RenderBox bar = c.findRenderObject();
    final RenderBox overlay = Overlay.of(c).context.findRenderObject();
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        bar.localToGlobal(bar.size.bottomRight(Offset.zero), ancestor: overlay),
        bar.localToGlobal(bar.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    return position;
  }
  void showBottomBar() {
    setState(() {
      _show = true;
      if (controller != null) controller.reverse();
    });
    Timer(Duration(seconds: TIME_TO_SHOW_CONTROLS), hideBottomBar);
    Timer(Duration(seconds: TIME_TO_SHOW_CONTROLS), stream.hideBar);
  }

  void hideBottomBar() {
    if (mounted) {
      setState(() {
        _show = false;
        controller.forward();
      });
    }
  }

  void tapped() {
    //if shown then hide  else show
    if (_show) {
      stream.hideBar();
      hideBottomBar();
    } else {
      stream.showBar();
      showBottomBar();
    }
  }

  void initMQTT() {
    FlutterLogs.logInfo("dashboard", "initMQTT", "xxxx setup mqtt in dashboard");
    final mqttClient = context.read<MQTTClient>();


    mqttClient.subscribe("galaxy/room/$_activeRoomId");
    mqttClient.subscribe("galaxy/room/$_activeRoomId/chat");

    mqttClient.addOnSubscribedCallback((topic) => subscribedToTopic(topic));
    mqttClient.addOnMsgReceivedCallback((payload) => handleCmdData(payload));
    mqttClient.addOnConnectionFailedCallback(() => handleConnectionFailed());
  }
}

void updateGxyUser(context, userData) async {
  Provider.of<MainStore>(context, listen: false).updaterUser(userData);
}

//
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onTap;
  final AppBar appBar;

  const CustomAppBar({Key key, this.onTap, this.appBar}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: appBar);
  }

  // TODO: implement preferredSize
  @override
  Size get preferredSize => new Size.fromHeight(kToolbarHeight);


}
