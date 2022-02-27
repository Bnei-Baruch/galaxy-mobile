import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:galaxy_mobile/mocks/chat.dart';
import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:galaxy_mobile/utils/topics.dart';
import 'package:galaxy_mobile/viewmodels/chat_view_model.dart';
import 'package:icon_badge/icon_badge.dart';
import 'package:mdi/mdi.dart';
import 'package:provider/provider.dart';
import 'package:phone_state_i/phone_state_i.dart';

import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_audio_manager/flutter_audio_manager.dart';

import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/screens/streaming/streaming.dart';
import 'package:galaxy_mobile/screens/video_room/videoRoomWidget.dart';
import 'package:galaxy_mobile/widgets/chat/chat_room.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:galaxy_mobile/widgets/loading_indicator.dart';
import 'package:galaxy_mobile/widgets/questions/questions_dialog_content.dart';
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
  ChatViewModel chatViewModel = ChatViewModel();
  var activeUser;
  int activeUserJoinedRoomTimestamp = 0;
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


    Connectivity().checkConnectivity().then((value) =>
        context.read<MainStore>().network = value
    );
    callInProgress = false;
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      // Got a new connectivity status!
      FlutterLogs.logInfo("Dashboard", "ConnectivityResult", result.toString());
      context.read<MainStore>().network = result;
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
        FlutterLogs.logInfo("Dashboard", "ConnectivityResult", "connection ${result.toString()}");
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
    videoRoom.onCurrentUserJoinedRoom = () {
      setState(() {
        activeUserJoinedRoomTimestamp = DateTime.now().millisecondsSinceEpoch;
      });
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
        if(userMap!=null)
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

    // For testing: Uncomment to mock incoming chat messages every 3 seconds.
    // createPeriodicMockChatMessages(chatViewModel, Duration(seconds: 3));
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

  void handleCmdData(String msgPayload, String topic) {
    FlutterLogs.logInfo(
        "Dashboard", "handleCmdData", "received message: $msgPayload topic: $topic");
    try {
      var jsonCmd = JsonDecoder().convert(msgPayload);
      TopicType topicType = Topics.parse(topic);
      switch (jsonCmd["type"]) {
        case "client-chat":
          if (topicType == TopicType.ROOM_CHAT) {
            chatViewModel.addChatMessage(
                ChatMessage.fromMQTTJson(
                    jsonCmd,
                    activeUser.id,
                    // TODO: the web version also does this. Doesn't MQTT
                    // have a timestamp as metadata?
                    DateTime.now().millisecondsSinceEpoch));
          }
          break;
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
    } else if (topic == "galaxy/room/$_activeRoomId/chat") {
      chatViewModel.setOnNewMessageCallback((ChatMessage message) {
        final mqttClient = context.read<MQTTClient>();
        mqttClient.send(topic, JsonEncoder().convert(message.toMQTTJson()));
        return true;
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
            // TODO: move to a function.
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
                      leadingWidth: 100,
                      leading: Row(children: <Widget>[
                        IconButton(
                          icon: setIcon(),
                          onPressed: () async {
                            await switchAudioDevice();
                            setState(() {});
                          }
                        ),
                        IconButton(
                          icon: ChangeNotifierProvider.value(
                            value: chatViewModel,
                                child: CommunicationsMenuIcon()
                            ),
                          onPressed: () => _displayCommunicationDialog(context)
                        ),
            ]),
                      actions: <Widget>[
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
                                      // TODO: move to central place.
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
                                  ? IconBadge(
                                  icon:Icon(Mdi.dotsVertical,color: Colors.red),
                                  itemCount: 2):
                                  IconBadge(icon:Icon(Mdi.dotsVertical,color: Colors.white),
                              itemCount: 2)
                          ),
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
                                  PopupMenuItem<String>(
                                    child: ListTile(
                                    leading: Icon(Icons.how_to_vote),
                                    title: Text('vote'.tr())),
                                    value: "4.1",
                                  ),
                                  PopupMenuItem<String>(
                                    child: ListTile(
                                    leading: Icon(Icons.supervisor_account_sharp),
                                    title: Text('friends'.tr())),
                                    enabled: true,
                                    value: "4.2",
                                  ),
                                ],
                              );
                              switch(result)
                              {
                                case "4.1": // Vote
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
                                case "4.2": // Friends (Participants)
                                  _displayParticipantsDialog(context);
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

  _displayCommunicationDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        Widget dialogHeader = Container(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          height: 42,
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.all(0)),
                  child: Container(
                    height: 42,
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          left: -4,
                          top: -2,
                          child: Icon(Mdi.chevronLeft, color: Colors.white, size: 42)
                        ),
                        Positioned(
                          left: 30,
                          top: 12,
                          child: Text("BACK", // TODO: translate
                            style: TextStyle(color: Colors.white, fontSize: 12)
                          )
                        )
                      ]
                    )
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ),
              Align(
                alignment: Alignment.center,
                child: Text("Communication", // TODO: translate
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
                )
              )
            ]
          )
        );

        return WillPopScope(
            onWillPop: () {
              Navigator.of(context).pop();
              return Future.value(true);
            },
            child: SafeArea(
              child: GestureDetector(
                  onTap: () {
                    // Hide keyboard when clicked outside a text field.
                    FocusScopeNode currentFocus = FocusScope.of(context);
                    if (!currentFocus.hasPrimaryFocus) {
                      currentFocus.unfocus();
                    }
                  },
                  child: Material(
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    //color: Colors.black26,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          dialogHeader,
                          Expanded(child:
                            TabContainer(
                              tabTitles: [
                                'CHAT', // TODO: translate
                                'SEND A QUESTION', // TODO: translate
                                // TODO: add support tab here.
                              ],
                              children: [
                                ChatRoom(chatViewModel: chatViewModel),
                                QuestionsDialogContent()
                              ]
                            )
                          )
                        ]
                    ),
                  ),
                )
            )
        ));
      },
    );
  }

  _displayParticipantsDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        List<RoomUser> users =
            // TODO: before moving the friends list into its own widget, active user's multimedia (camOn, micOn) state should live
            // in a model.
        [RoomUser(id: activeUser.id, name: activeUser.name, camOn: !videoMute, micOn: !audioMute, isCurrentUser: true, timeJoined: activeUserJoinedRoomTimestamp)]
                + context.select((MainStore s) => s.friendsInRoom);
        users.sort((a, b) => a.timeJoined.compareTo(b.timeJoined));

        return WillPopScope(
          onWillPop: () {
            Navigator.of(context).pop();
            return Future.value(true);
          },
          child: SafeArea(
            child: Material(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(15),
                color: Colors.black26,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      height: 45.0,
                      child: Stack(
                        children: <Widget>[
                          Positioned(
                            left: 0,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text("close".tr(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Text("friends".tr() + " (" + users.length.toString() + ")",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                          )
                        ]
                      )
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 5.0),
                      child: const Divider(
                        thickness: 1,
                        color: Colors.grey,
                    )),
                    Expanded(child: ListView(
                      children: users.map(
                          (user) => Container(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: <Widget>[
                                  const Icon(Icons.account_box, size: 50),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Text(user.name, style: TextStyle(
                                    color: user.isCurrentUser ? Color(0xff00c6d2) :Colors.white,
                                    fontSize: 18,
                                  )),
                                  const Spacer(),
                                  Icon(
                                      user.micOn ? Icons.mic : Icons.mic_off,
                                      color: user.micOn ? Colors.white : Colors.red,
                                      size: 30),
                                  const SizedBox(
                                    width: 6,
                                  ),
                                  Icon(
                                      user.camOn ? Icons.videocam : Icons.videocam_off,
                                      color: user.camOn ? Colors.white : Colors.red,
                                      size: 30),
                              ])
                          )).toList()
                      )
                    )
                  ]
                ),
              ),
            )
          )
        );
      },
    );
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
    mqttClient.addOnMsgReceivedCallback((payload, topic) => handleCmdData(payload, topic));
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

class CommunicationsMenuIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CommunicationsIconBadge(
        right: 0,
        top: 0,
        width: 36,
        hideZero: true,
        icon: Icon(
            Mdi.forum,
            color: Colors.white
        ),
        itemCount: context.select((ChatViewModel model) => model.unreadMessagesCount)
    );
  }
}

class CommunicationsIconBadge extends StatelessWidget {
  final double width;
  final Icon icon;
  final VoidCallback onTap;
  final int itemCount;
  final bool hideZero;
  final Color badgeColor;
  final Color itemColor;
  final double top;
  final double right;
  final int maxCount;

  const CommunicationsIconBadge({
    Key key,
    this.onTap,
    @required this.icon,
    this.itemCount = 0,
    this.hideZero = false,
    this.badgeColor = Colors.red,
    this.itemColor = Colors.white,
    this.width = 72,
    this.maxCount = 99,
    this.top = 3.0,
    this.right = 6.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return itemCount == 0 && hideZero
        ? GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                icon,
              ],
            ),
          ],
        ),
      ),
    )
        : GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                icon,
              ],
            ),
            Positioned(
              top: top,
              right: right,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50.0),
                  color: badgeColor,
                ),
                alignment: Alignment.center,
                child: itemCount > maxCount
                    ? Text(
                  '$maxCount+',
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 10.0,
                  ),
                )
                    : Text(
                  '$itemCount',
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 10.0,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class TabContainer extends StatefulWidget {
  final List<Widget> children;
  final List<String> tabTitles;

  TabContainer({
    Key key,
    @required this.children,
    @required this.tabTitles
  }) : assert(children != null),
        assert(children.length == tabTitles.length),
        super(key: key);

  @override
  _TabContainerState createState() => _TabContainerState();
}

class _TabContainerState extends State<TabContainer> {
  int _activeIndex;

  void _changeTab(int index) {
    if (index != _activeIndex) {
      this.setState(() {
        _activeIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _activeIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    Orientation orientation = MediaQuery.of(context).orientation;
    return Flex(
            mainAxisAlignment: MainAxisAlignment.start,
            direction: orientation == Orientation.landscape
                ? Axis.horizontal
                : Axis.vertical,
        children: [
          Flex(
            mainAxisAlignment: MainAxisAlignment.start,
              direction: orientation == Orientation.landscape
                  ? Axis.vertical
                  : Axis.horizontal,
            children: widget.tabTitles.asMap().entries.map((entry) {
              int idx = entry.key;
              String title = entry.value;
            return Expanded(
                flex: orientation == Orientation.landscape ? 0 : 1,
                child:
              GestureDetector(
                onTap: () => this._changeTab(idx),
                child: Container(
                  margin: orientation == Orientation.landscape ? EdgeInsets.symmetric(horizontal: 6) : null,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white),
                    color: idx == _activeIndex ? Colors.white : Colors.black12,
                  ),
                  child: SizedBox(
                    width: orientation == Orientation.landscape ? 160 : null,
                    height: 40,
                    child: Center(
                      child: Text(title,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                              color: idx == _activeIndex ? Colors.black87 : Colors.white,
                              fontWeight: FontWeight.bold
                            )
                          ),
                      widthFactor: 1.0,
                    ),
                  )
                )
              )
            );
          }).toList()),
      Expanded(child: widget.children[_activeIndex])
    ]);
  }
}
