import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:async/async.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:galaxy_mobile/mocks/chat.dart';
import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:galaxy_mobile/utils/ambient_direction.dart';
import 'package:galaxy_mobile/utils/topics.dart';
import 'package:galaxy_mobile/viewmodels/chat_view_model.dart';
import 'package:headset_connection_event/headset_event.dart';
import 'package:icon_badge/icon_badge.dart';
import 'package:janus_client/janus_client.dart';
import 'package:mdi/mdi.dart';
import 'package:phonecall_state/phone_state_i.dart';
import 'package:provider/provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_audio_manager/flutter_audio_manager.dart';

import 'package:galaxy_mobile/models/main_store.dart';
import 'package:galaxy_mobile/screens/streaming/streaming.dart';
import 'package:galaxy_mobile/screens/video_room/video_room_widget.dart';
import 'package:galaxy_mobile/widgets/chat/chat_room.dart';
import 'package:galaxy_mobile/widgets/dialog/main_dialog_header.dart';
import 'package:galaxy_mobile/widgets/dialog/study_materials_dialog.dart';
import 'package:galaxy_mobile/services/mqtt_client.dart';
import 'package:galaxy_mobile/widgets/loading_indicator.dart';
import 'package:galaxy_mobile/widgets/questions/questions_dialog_content.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum AudioDevice { headphones, receiver,speaker, bluetooth }

final int SECONDS_TO_SHOW_CONTROLS = 10;

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
  var mqttClient;
  int activeUserJoinedRoomTimestamp = 0;
  bool callInProgress;
  String _activeRoomId;
  AudioDevice _audioDevice = AudioDevice.receiver;

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

  bool _barsShown = false;
  RestartableTimer _hideBarsTimer;

  int pagePosition = 0;

  int feedsLength = 1;

  AnimationController controller;
  Animation<Offset> offset;

  var  activeRoom;

  bool isChangingAudioRoute = false;

  bool btConnected = false;

  List<AudioInput> availableInputs;
  List<MediaDeviceInfo> availableInputsWebRTC;

  bool headPhonesConnected = false;

  HeadsetEvent headsetPlugin = HeadsetEvent();

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
            subscription.cancel();

            Navigator.pop(dialogPleaseWaitContext);
            Navigator.of(context).pop();
          }
        });
        //show message on screen
      } else {

        // //if marked no connection then reneter room
        // if(dialogPleaseWaitContext!=null) {
        //   Navigator.pop(dialogPleaseWaitContext);
        //   dialogPleaseWaitContext = null;
        // }
        // FlutterLogs.logInfo("Dashboard", "ConnectivityResult", "connection ${result.toString()}");
        // if (hadNoConnection || (context.read<MainStore>().network != result)) {
        //   FlutterLogs.logInfo(
        //       "Dashboard", "ConnectivityResult", "reconnecting - exit room");
        //
        //   FlutterLogs.logInfo(
        //       "Dashboard", "ConnectivityResult", "reconnecting - enter room");
        //   //enter room
        //   setState(() {
        //
        //     //recover mqtt connection
        //     stream.exit();
        //     videoRoom.exitRoom();
        //
        //     userTimer.cancel();
        //     //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
        //     Navigator.of(this.context).pop(false);
        //     //callReEnter();
        //   });
        //   hadNoConnection = false;
        // }
      }
      setState(() {
        context.read<MainStore>().network = result;
      });

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
        FlutterLogs.logInfo("Dashboard", "phoneCall", "mark re-enter, conversation is in progress");
        callInProgress = true;
        stream.state.playerOverlay.muteStreamIfNeeded();
        videoRoom.unMute();
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
          subscription.cancel();
          userTimer.cancel();

          //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
          Navigator.of(this.context).pop(false);
          callReEnter();
        });
      }
    });

    videoRoom.onPageChange = (int position, int feedsLength) {
      if (mounted) {
        setState(() {
          hideBars();
          this.pagePosition = position;
          this.feedsLength = feedsLength;
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
      toggleBarsVisibility();
      //changeAudioDevice(AudioDevice.values.firstWhere((element) =>element.index == context.read<MainStore>().getAudioDevice()));

    };
    videoRoom.updateGoingToBackground = (){
     updateRoomWithMyState(false);
    };
    videoRoom.resetAudioRoute = () async {

      var current_output = await FlutterAudioManager.getCurrentOutput();
      if(current_output.port.index != context.read<MainStore>().getAudioDevice())
          changeAudioDevice(AudioDevice.values.firstWhere((element) =>element.index == context.read<MainStore>().getAudioDevice()));
    };
    videoRoom.callExitRoomUserExists = () {
      stream.exit();
      videoRoom.exitRoom();
      userTimer.cancel();
      subscription.cancel();

      showDialog(
        context: context,
        builder: (context) => new AlertDialog(
          title: new Text('Room Message'),
          content: Text('Your user is already in the room'),
          actions: <Widget>[
            new TextButton(
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
    mqttClient = context.read<MQTTClient>();
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

    stream.audioPlay = (isPlaying) {
      if(isPlaying)
        {
          switchAudioDevice();
        }
    };

    _hideBarsTimer = RestartableTimer(Duration(seconds: SECONDS_TO_SHOW_CONTROLS), hideBars);
    // The timer starts as inactive.
    _hideBarsTimer.cancel();
    // For testing: Uncomment to mock incoming chat messages every 3 seconds.
    // createPeriodicMockChatMessages(chatViewModel, Duration(seconds: 3));
  }

  Future<void> initAudioMgr() async {

    //if bt is already connected use it, if not use headhones if none connected divert to speaker
    //if headphones or bt got disconnected divert to one of them otherwise go to reciever
    //if headphones or bt get connected divert to them
    routeAudioOutput(AudioDevice.receiver);
    availableInputsWebRTC = await Helper.enumerateDevices("audiooutput");
    FlutterLogs.logInfo("dashboard", "audio manager", "init");

     headsetPlugin.setListener((_val) async{

       //in case of disconnection we first route to receiver to prevent any sudden speaker later we check if we need to route to headphones
       if(_val == HeadsetState.DISCONNECT)
         {
           routeAudioOutput(AudioDevice.receiver);
         }

      FlutterLogs.logInfo("dashboard", "audio manager", "headsetPlugin $_val changed");
      Future.delayed(Duration(seconds: 1),() async {
        var output = await Helper.enumerateDevices("audiooutput");
        var input = await Helper.enumerateDevices("audioinput");

        //for ios we need to use the groupid indication, chnage it to lower case in when bluetooth check contains bluetooth
        FlutterLogs.logInfo("dashboard", "audio manager", "connection changed output ${output.map((e) => e.deviceId)} connection changed input ${input.map((e) => e.deviceId)}");
        FlutterLogs.logInfo("dashboard", "audio manager", "connection changed output2 ${output.map((e) => e.label)} connection changed input2 ${input.map((e) => e.label)}");
        FlutterLogs.logInfo("dashboard", "audio manager", "connection changed output3 ${output.map((e) => e.kind)} connection changed input3 ${input.map((e) => e.kind)}");
        FlutterLogs.logInfo("dashboard", "audio manager", "connection changed output3 ${output.map((e) => e.groupId)} connection changed input3 ${input.map((e) => e.groupId)}");
       availableInputs = await FlutterAudioManager.getAvailableInputs();
       FlutterLogs.logInfo("dashboard", "audio manager", "availableInputs $availableInputs");
       print("headset event $_val");
       if(_val == HeadsetState.CONNECT)
         {
           if(output.any((element) => element.deviceId == AudioPort.bluetooth.name || element.groupId.toLowerCase().contains(AudioPort.bluetooth.name)))
           {
             FlutterLogs.logInfo("dashboard", "audio manager", "bt connected -> route to bluetooth");
             routeAudioOutput(AudioDevice.bluetooth);
             btConnected = true;
           }
           else if(output.any((element) => element.deviceId == AudioPort.headphones.name || element.groupId.toLowerCase() == AudioPort.headphones.name ))
           {
             FlutterLogs.logInfo("dashboard", "audio manager", "headphones connected -> route to headphones");
             routeAudioOutput(AudioDevice.headphones);
             headPhonesConnected = true;
           }
         }
       else {

         //if bluetooth disconnected and headphone connected to route to headphnes
         //if bt disconnected
         if((output.every((element) => element.deviceId != AudioPort.bluetooth.name || (!element.groupId.toLowerCase().contains(AudioPort.bluetooth.name)))) && btConnected)
         {
           FlutterLogs.logInfo("dashboard", "audio manager", "bt not connected -> route to receiver");
           btConnected = false;
         }
          if(output.any((element) => element.deviceId == AudioPort.headphones.name || element.groupId.toLowerCase() == AudioPort.headphones.name ))
         {
           FlutterLogs.logInfo("dashboard", "audio manager", "headphones connected -> route to headphones");
           headPhonesConnected = true;
           routeAudioOutput(AudioDevice.headphones);
         }
          else
            {
              headPhonesConnected = false;
              routeAudioOutput(AudioDevice.receiver);
            }
       }
        });
    });
    FlutterAudioManager.setListener(() async {
      // var current = await FlutterAudioManager.getCurrentOutput();
      // FlutterLogs.logInfo(
      //     "VideoRoom", "audio manager", "audio device changed $current");
      //
      // availableInputs = await FlutterAudioManager.getAvailableInputs();
      // FlutterLogs.logInfo("dashboard", "audio manager", "availableInputs2 $availableInputs");
      //
      // List<AudioInput> inputs = await FlutterAudioManager.getAvailableInputs();
      // FlutterLogs.logInfo("dashboard", "audio manager", "availableInputs3 $availableInputs");
      // //if bt disconnected
      // if(inputs.every((element) => element.port != AudioPort.bluetooth) && btConnected)
      // {
      //   FlutterLogs.logInfo("dashboard", "audio manager", "bt not connected -> route to receiver");
      //   btConnected = false;
      //   routeAudioOutput(AudioDevice.receiver);
      // }
      // else if(inputs.every((element) => element.port != AudioPort.headphones) && headPhonesConnected)
      // {
      //   FlutterLogs.logInfo("dashboard", "audio manager", "headphones not connected -> route to receiver");
      //   headPhonesConnected = false;
      //   routeAudioOutput(AudioDevice.receiver);
      // }


      var output = await Helper.enumerateDevices("audiooutput");
      var input = await Helper.enumerateDevices("audioinput");
      FlutterLogs.logInfo("dashboard", "audio manager", "changed output ${output.map((e) => e.deviceId)} changed input ${input.map((e) => e.deviceId)}");
      if(WebRTC.platformIsIOS) { //in ios env we loose the route when Janus gets and event
        // if (current.name.toLowerCase() != _audioDevice.name &&
        //     !isChangingAudioRoute) {
        //   if (await changeAudioDevice(_audioDevice)) {
        //     FlutterLogs.logInfo(
        //         "dashboard", "initAudioMgr",
        //         "zzz reset and  switch  back to  ${_audioDevice
        //             .toString()}: Success");
        //   } else {
        //     FlutterLogs.logError(
        //         "dashboard", "initAudioMgr",
        //         "zzz reset and  switch  back to  ${_audioDevice
        //             .toString()}:: Failed");
        //   }
        // }
      }
      // setState(() {
      //
      // });
    });


    var output = await Helper.enumerateDevices("audiooutput"); //earpiece, speaker, bluetooth
    var input = await Helper.enumerateDevices("audioinput");
    FlutterLogs.logInfo("dashboard", "audio manager", "output ${output.map((e) => e.deviceId)}  input ${input.map((e) => e.deviceId)}");
    //first time audio init we fall through decision tree to set the correct output
    // if bt available we set it, otherwise if headphones we set it, fallback goes to speaker, if bt and headphones disconnects it goes to receiver

    FlutterLogs.logInfo("dashboard", "audio manager", "availableInputs = ${output.map((e) => e.deviceId)}");
    //if bt connected
    if(output.any((element) => element.deviceId == AudioPort.bluetooth.name || (element.groupId!=null && element.groupId.toLowerCase().contains(AudioPort.bluetooth.name))))
    {
      FlutterLogs.logInfo("dashboard", "audio manager", "bt connected -> route to bluetooth");
      routeAudioOutput(AudioDevice.bluetooth);
      btConnected = true;
    }
    else if(output.any((element) => element.deviceId == AudioPort.headphones.name || (element.groupId!=null && element.groupId.toLowerCase() == AudioPort.headphones.name)))
    {
      FlutterLogs.logInfo("dashboard", "audio manager", "headphones connected -> route to headphones");
      routeAudioOutput(AudioDevice.headphones);
      headPhonesConnected = true;
    }
    else
    {
      FlutterLogs.logInfo("dashboard", "audio manager", "none connected -> route to speaker");
      routeAudioOutput(AudioDevice.speaker);
    }

  }

  switchAudioDevice() async {

    isChangingAudioRoute = true;

    await routeAudioOutput();

    isChangingAudioRoute = false;

  }

  Future<void> routeAudioOutput([AudioDevice toOutput]) async {
       FlutterLogs.logInfo(
        "dashboard", "switchAudioDevice", "#### switchAudioDevice BEGIN toOutput $toOutput  availableInputs $availableInputs");
    bool res;
       availableInputsWebRTC = await Helper.enumerateDevices("audiooutput");

       List<AudioDevice> devices = [AudioDevice.receiver,AudioDevice.speaker,AudioDevice.bluetooth,AudioDevice.headphones];
    switch(toOutput)
    {
      case AudioDevice.bluetooth:
        context
            .read<MainStore>()
            .setAudioDevice(AudioDevice.bluetooth.index);
        await changeAudioDevice(AudioDevice.bluetooth);
        break;
      case AudioDevice.receiver:
        context
            .read<MainStore>()
            .setAudioDevice(AudioDevice.receiver.index);
        await changeAudioDevice(AudioDevice.receiver);
        break;
      case AudioDevice.speaker:
        context
            .read<MainStore>()
            .setAudioDevice(AudioDevice.speaker.index);
        await changeAudioDevice(AudioDevice.speaker);
        break;
      case AudioDevice.headphones:
        context
            .read<MainStore>()
            .setAudioDevice(AudioDevice.headphones.index);
        await changeAudioDevice(AudioDevice.headphones);
        break;
      default:
        //go through next available output
      //remove bt or headphones if not available
        if(availableInputsWebRTC.every((element) => element.deviceId != AudioPort.bluetooth.name && (element.groupId==null || (element.groupId!=null && !element.groupId.toLowerCase().contains(AudioPort.bluetooth.name)))))
        {
          //remove bluetooth from list
          devices.remove(AudioDevice.bluetooth);
        }
        if(availableInputsWebRTC.every((element) => element.deviceId != AudioPort.headphones.name &&  (element.groupId==null || (element.groupId!=null && element.groupId.toLowerCase() != AudioPort.headphones.name))))
          {
            devices.remove(AudioDevice.headphones);
          }

        var changeTo;
        if(devices.indexOf(_audioDevice)== devices.length-1)
          changeTo = devices[0];
        else
          changeTo = devices[devices.indexOf(devices.firstWhere((element) => _audioDevice == element))+1];

        context
            .read<MainStore>()
            .setAudioDevice((changeTo as AudioDevice).index);
        await changeAudioDevice(changeTo);
        // if (_audioDevice == AudioDevice.receiver) {
        //   context
        //         .read<MainStore>()
        //         .setAudioDevice(AudioDevice.speaker.index);
        //   res = await changeAudioDevice(AudioDevice.speaker);
        //
        // }
        // else if (_audioDevice == AudioDevice.speaker) {
        //   context
        //       .read<MainStore>()
        //       .setAudioDevice(AudioDevice.receiver.index);
        //   res = await changeAudioDevice(AudioDevice.receiver);
        // }
        // else if (_audioDevice == AudioDevice.bluetooth) {
        //   context
        //       .read<MainStore>()
        //       .setAudioDevice(AudioDevice.receiver.index);
        //   res = await changeAudioDevice(AudioDevice.receiver);
        // }
        break;

    }
    setState(() {

    });
    // if(toOutput == AudioDevice.bluetooth) {
    //   _audioDevice = AudioDevice.bluetooth;
    //   await changeAudioDevice(AudioDevice.bluetooth);
    //
    //   // else
    //   //   _audioDevice = AudioDevice.values[(context.read<MainStore>().audioDevice)];
    // }
    // if (_audioDevice == AudioDevice.receiver) {
    //   res = await changeAudioDevice(AudioDevice.speaker);
      // if (res) {
      //   FlutterLogs.logInfo(
      //       "dashboard", "switchAudioDevice", ">>> switch to SPEAKER: Success");
      //   context
      //       .read<MainStore>()
      //       .setAudioDevice(AudioDevice.speaker.index);
      // } else {
      //   FlutterLogs.logError(
      //       "dashboard", "switchAudioDevice", ">>> switch to SPEAKER: Failed");
      // }
    // }
    // else if (_audioDevice == AudioDevice.speaker) {
    //   res = await changeAudioDevice(AudioDevice.bluetooth);
    //   AudioInput currentOutput = await FlutterAudioManager.getCurrentOutput();
    //   if (res && currentOutput.port == AudioPort.bluetooth) {
    //     FlutterLogs.logInfo("dashboard", "switchAudioDevice",
    //         ">>> switch to BLUETOOTH: Success");
    //     context
    //         .read<MainStore>()
    //         .setAudioDevice(AudioDevice.bluetooth.index);
    //   } else {
    //     FlutterLogs.logError("dashboard", "switchAudioDevice",
    //         ">>> switch to BLUETOOTH: Failed");
    //     res = await changeAudioDevice(AudioDevice.receiver);
    //     if (res) {
    //       FlutterLogs.logInfo("dashboard", "switchAudioDevice",
    //           ">>> switch to RECEIVER: Success");
    //       context
    //           .read<MainStore>()
    //           .setAudioDevice(AudioDevice.receiver.index);
    //     } else {
    //       FlutterLogs.logError("dashboard", "switchAudioDevice",
    //           ">>> switch to RECEIVER: Failed");
    //     }
    //   }
    //
    // } else if (_audioDevice == AudioDevice.bluetooth) {
    //   res = await changeAudioDevice(AudioDevice.receiver);
    //   if (res) {
    //     FlutterLogs.logInfo("dashboard", "switchAudioDevice",
    //         ">>> switch to RECEIVER: Success");
    //     context
    //         .read<MainStore>()
    //         .setAudioDevice(AudioDevice.receiver.index);
    //   } else {
    //     FlutterLogs.logError(
    //         "dashboard", "switchAudioDevice", ">>> switch to RECEIVER: Failed");
    //   }
    // }

    FlutterLogs.logInfo(
        "dashboard", "switchAudioDevice", "#### switchAudioDevice END");
  }



  changeAudioDevice(AudioDevice audioDevice) async {
    FlutterLogs.logInfo(  "dashboard", "zz audiooutputs", (await Helper.audiooutputs).map((e) => e.deviceId.toString()).toList().toString());
    bool res = false;
    isChangingAudioRoute = true;
    switch (audioDevice) {
      case AudioDevice.receiver:
        await Helper.setSpeakerphoneOn(false);

       await Helper.selectAudioOutput("earpiece");
        res = await FlutterAudioManager.changeToReceiver();
        break;
      case AudioDevice.speaker:
        await Helper.setSpeakerphoneOn(true);
        await Helper.selectAudioOutput("speaker");
        res = await FlutterAudioManager.changeToSpeaker();
        break;
      case AudioDevice.bluetooth:
        await Helper.setSpeakerphoneOn(false);
        await Helper.selectAudioOutput("bluetooth");
        res = await FlutterAudioManager.changeToBluetooth();
        break;
      case AudioDevice.headphones:
        await Helper.setSpeakerphoneOn(false);
        res = await FlutterAudioManager.changeToHeadphones();
        break;
      default:
        FlutterLogs.logError("dashboard", "changeAudioDevice",
            "invalid audio device: ${audioDevice.toString()}");
    }
    isChangingAudioRoute = false;
    return res;
  }

  void handleCmdData(String msgPayload, String topic) {
    FlutterLogs.logInfo(
        "Dashboard", "handleCmdData", "received message: $msgPayload topic: $topic");
    var jsonCmd;
    try {
      String utf8DecodedPayload = utf8.decode(
          msgPayload.runes.toList(),
          allowMalformed: true);
      jsonCmd = json.decode(utf8DecodedPayload);
    } on FormatException catch (e) {
      FlutterLogs.logError("Dashboard", "handleCmdData",
          "Could not decode JSON in UTF8: ${e.toString()}");
      return;
    }

    FlutterLogs.logInfo(
        "Dashboard", "handleCmdData", "decoded json: $jsonCmd");
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
  }

  void handleConnectionFailed() {
    stream.exit();
    videoRoom.exitRoom();
    userTimer.cancel();
    subscription.cancel();

    showDialog(
      context: context,
      builder: (context) => new AlertDialog(
        title: new Text('Room Message'),
        content: Text('Connection to server failure'),
        actions: <Widget>[
          new TextButton(
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
    FlutterLogs.logInfo(
        "Dashboard", "subscribedToTopic", "topic = $topic");
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
        mqttClient.send(topic,  String.fromCharCodes(JsonUtf8Encoder().convert(message.toMQTTJson())));
        return true;
      });
    }
  }

  @override
  void didChangeDependencies() async {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
  }
  void updateRoomWithMyState(bool isQuestion) {
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
        "galaxy/room/" + _activeRoomId, String.fromCharCodes(JsonUtf8Encoder().convert(message)));
    userMap = userData;
  }

  Icon setIcon() {

    _audioDevice = AudioDevice.values[(context.read<MainStore>().audioDevice)];
    FlutterLogs.logInfo("dashboard", "setIcon", "#### setIcon BEGIN audioDevice $_audioDevice");
    if (_audioDevice == AudioDevice.receiver) {
      return Icon(Mdi.volumeMute);
    } else if (_audioDevice == AudioDevice.speaker) {
      return Icon(Icons.volume_up);
    } else if (_audioDevice == AudioDevice.bluetooth) {
      return Icon(Icons.bluetooth);
    }if (_audioDevice == AudioDevice.headphones) {
      return Icon(Icons.headphones);
    } else {
      return Icon(Icons.do_not_disturb);
    }
  }


  @override
  Widget build(BuildContext context) {

    return WillPopScope(
        onWillPop: () {
          final mqttClient = context.read<MQTTClient>();

          stream.exit();
          videoRoom.exitRoom();
          userTimer.cancel();
          subscription.cancel();

          if (mqttClient != null) {
            mqttClient.unsubscribe("galaxy/room/$_activeRoomId");
            // TODO: move to a function.
            mqttClient.unsubscribe("galaxy/room/$_activeRoomId/chat");
            mqttClient.removeOnConnectedCallback();
            mqttClient.removeOnConnectionFailedCallback();
            mqttClient.clearOnMsgReceivedCallback();
            mqttClient.removeOnSubscribedCallback();
          }
          //changeAudioDevice(AudioDevice.receiver);
          Navigator.of(context).pop(true);
          return;
        },
        child: Scaffold(
          appBar: isFullScreen
              ? null
              : !_barsShown
                  ? CustomAppBar(
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        iconTheme: IconThemeData(color: Colors.transparent),
                        automaticallyImplyLeading: false,
                      ),
                      onTap: () => toggleBarsVisibility(),
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

                                    subscription.cancel();
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
                                    Navigator.of(context).pop(true);
                                  }))
                        ]),
          body: GestureDetector(
              onTap: () => toggleBarsVisibility(),
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
                        onTap: () => toggleBarsVisibility(),
                        child: Container(
                          color: Colors.black,
                          height: kBottomNavigationBarHeight,
                          child: Align(
                            alignment: Alignment.center,
                            child: DotsIndicator(
                                reversed: getAmbientDirection(context) == ui.TextDirection.rtl,
                                dotsCount: getNumPages(feedsLength) > 0
                                    ? getNumPages(feedsLength)
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
                              icon: IconBadge(
                                  icon: Icon(
                                    Mdi.dotsVertical, color: Colors.white),
                                  itemCount: 4
                              )
                          ),
                        ],
                        onTap: (value) async {
                          FlutterLogs.logInfo(
                              "Dashboard", "onTap", value.toString());
                          switch (value) {
                            case 0:
                              videoRoom.toggleMute();
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
                                      title: Text('vote'.tr())
                                    ),
                                    value: "4.1",
                                  ),
                                  PopupMenuItem<String>(
                                    child: ListTile(
                                      leading: Icon(Icons.supervisor_account_sharp),
                                      title: Text('friends'.tr())
                                    ),
                                    enabled: true,
                                    value: "4.2",
                                  ),
                                  PopupMenuItem<String>(
                                    child: ListTile(

                                      leading: Icon(Icons.auto_stories),
                                      title: Text('study_material'.tr())
                                    ),
                                    enabled: true,
                                    value: "4.3",
                                  ),
                                    PopupMenuItem<String>(
                                    child: ListTile(

                                     leading: Icon(Icons.favorite,color: Colors.red,),
                                      title: Text('donate'.tr()),
                                    ),
                                    enabled: true,
                                    value: "4.4",
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

                                case "4.3": // Study material
                                  displayStudyMaterialDialog(context);

                                  break;
                              case "4.4": // Donate
                              _openDonationLink(context);
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
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          MainDialogHeader(
                              title: "communication.title".tr(),
                              onBackPressed: () => Navigator.of(context).pop()
                          ),
                          Expanded(child:
                            TabContainer(
                              tabTitles: [
                                "communication.chat_tab_title".tr().toUpperCase(),
                                "communication.question_tab_title".tr().toUpperCase(),
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

  void showBars() {
    if (!mounted) {
      return;
    }

    stream.showBar();
    setState(() {
      _barsShown = true;
      controller?.reverse();
    });
    _hideBarsTimer.reset();
  }

  void hideBars() {
    if (!mounted) {
      return;
    }

    stream.hideBar();
    setState(() {
      _barsShown = false;
      controller?.forward();
    });
    _hideBarsTimer.cancel();
  }

  void toggleBarsVisibility() {
    if (_barsShown) {
      hideBars();
    } else {
      showBars();
    }
  }

  void initMQTT() {
    FlutterLogs.logInfo("dashboard", "initMQTT", "xxxx setup mqtt in dashboard");
    final mqttClient = context.read<MQTTClient>();



    mqttClient.addOnSubscribedCallback((topic) => subscribedToTopic(topic));
    mqttClient.addOnMsgReceivedCallback((payload, topic) => handleCmdData(payload, topic));

    mqttClient.addOnConnectionFailedCallback(() => handleConnectionFailed());
    mqttClient.addOnConnectedCallback(() => handleConnected());

    mqttClient.subscribe("galaxy/room/$_activeRoomId");
    mqttClient.subscribe("galaxy/room/$_activeRoomId/chat");
  }

  void _openDonationLink(BuildContext context) {


        var urllaunchable =  canLaunch("donation_url".tr()); //canLaunch is from url_launcher package
        if(urllaunchable != null){
           launch("donation_url".tr()); //launch is from url_launcher package to launch URL
        }else{
          print("URL can't be launched.");
        }

  }

  handleConnected() {
    FlutterLogs.
    logInfo(
        "Dashboard", "mqtt", "handleConnected");
    //if marked no connection then reneter room
    if(dialogPleaseWaitContext!=null) {
      Navigator.pop(dialogPleaseWaitContext);
      dialogPleaseWaitContext = null;
    }
    // FlutterLogs.logInfo("Dashboard", "ConnectivityResult", "connection ${result.toString()}");
    // if (hadNoConnection || (context.read<MainStore>().network != result)) {



      //enter room
      setState(() {
        FlutterLogs.logInfo(
            "Dashboard", "ConnectivityResult", "reconnecting - exit room");
        //recover mqtt connection
        stream.exit();
        videoRoom.exitRoom();
        subscription.cancel();
        userTimer.cancel();
        //go out of the room and re-enter , since jauns doesn't have a reconnect infra to do it right
        Navigator.of(this.context).pop(false);
        //callReEnter();
      });
      hadNoConnection = false;
    // }

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
