import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/main_store.dart';
import 'package:galaxy_mobile/services/logger.dart';
import 'package:galaxy_mobile/services/mqtt_client.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:galaxy_mobile/widgets/dialog/study_materials_dialog.dart';
import 'package:galaxy_mobile/widgets/audio_mode.dart';
import 'package:galaxy_mobile/widgets/drawer.dart';
import 'package:galaxy_mobile/widgets/room_selector.dart';
import 'package:galaxy_mobile/widgets/screen_loader.dart';
import 'package:galaxy_mobile/widgets/ui_language_selector.dart';
import 'package:galaxy_mobile/widgets/horizontal_flip.dart';

import 'package:provider/provider.dart';
import 'package:galaxy_mobile/widgets/screen_name.dart';
import 'package:galaxy_mobile/widgets/self_view_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final logger = new Logger("settings");

class Settings extends StatefulWidget {
  @override
  State createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with WidgetsBindingObserver {
  SelfViewWidget selfWidget;

  StreamSubscription<ConnectivityResult> subscription;
  ConnectivityResult connectionStatus;
  SendPort mainToIsolateStream;

  var userJsonExtra;
  var monitorData;

  BuildContext dialogPleaseWaitContext;
  BuildContext dialogContext;

  @override
  Future<void> initState() {
    super.initState();
    logger.info("starting settings");
    WidgetsBinding.instance.addObserver(this);
    final mqttClient = context.read<MQTTClient>();
    selfWidget = SelfViewWidget();

    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
          connectionStatus = result;
        });
    Utils.parseJson("user_monitor_example.json")
        .then((value) => userJsonExtra = value);
    Utils.parseJson("monitor_data.json").then((value) => monitorData = value);

    mqttClient.addOnDisconnectedCallback(()  {
      FlutterLogs.logError("Settings", "onDisconnected","mqtt got disconnected" );
      setState(() {});
    });
    mqttClient.addOnConnectedCallback(()  {
      if (dialogPleaseWaitContext != null) {
        Navigator.of(dialogPleaseWaitContext).pop();
      }
      setState(() {});

      mqttClient.subscribe("galaxy/users/broadcast");
      var user = context.read<MainStore>().activeUser;
      mqttClient.subscribe("galaxy/users/${user.id}");
    });
    mqttClient.addOnConnectionFailedCallback(() => {
      if (dialogContext == null) {
        showDialog(
          context: context,
          builder: (context) {
            dialogContext = context;
            return AlertDialog(
              title: new Text('Connection Message'),
              content: Text(
                  'Server is unreachable,\nplease make sure internet connection is available'),
              actions: <Widget>[
                new TextButton(
                  onPressed: () {
                    Navigator.of(this.dialogContext, rootNavigator: true).pop();
                    dialogContext = null;
                    mqttClient.connect(user: context.read<MainStore>().activeUser);
                    // dismisses only the dialog and returns nothing
                  },
                  child: new Text('OK'),
                ),
              ],
            );
          }
        )
      }
    });

    mqttClient.connect(user: context.read<MainStore>().activeUser);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
        FlutterLogs.logInfo("Settings", "appLifeCycleState", "inactive");
        selfWidget.stopCamera();
        break;
      case AppLifecycleState.resumed:
        FlutterLogs.logInfo("Settings", "appLifeCycleState", "resumed");
        selfWidget.restartCamera();
        break;
      case AppLifecycleState.paused:
        FlutterLogs.logInfo("Settings", "appLifeCycleState", "paused");
        selfWidget.stopCamera();
        break;
      case AppLifecycleState.detached:
        FlutterLogs.logInfo("Settings", "appLifeCycleState", "detached");
        selfWidget.stopCamera();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    var activeUser = context.select((MainStore s) => s.activeUser);
    bool isThinScreen = MediaQuery.of(context).size.width < 400;
    final mqttClient = context.read<MQTTClient>();
    FlutterLogs.logInfo("Settings", "build", "mqtt connect state ${mqttClient.isConnected()}");
    return (!mqttClient.isConnected())
        ? ScreenLoader()
        : Scaffold(
        appBar: AppBar(
          title: Text("settings".tr()),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.auto_stories),
              onPressed: () {
                displayStudyMaterialDialog(context);
              }
          )]
        ),
        drawer: AppDrawer(),
        body: LayoutBuilder(builder:
            (BuildContext context, BoxConstraints viewportConstraints) {
          return SingleChildScrollView(
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        Row(children: [
                          SizedBox(width: 10.w),
                          Flexible(
                              child: Container(
                                  padding: EdgeInsets.only(right: 13.0),
                                  width: MediaQuery.of(context).size.width *
                                      0.9,
                                  child: Text(
                                      "hello_user".tr(args: [
                                        '${activeUser.givenName}'
                                      ]),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.normal)))),
                          SizedBox(width: 10.w)
                        ]),
                        SizedBox(height: 10.h),
                        Row(children: [
                          SizedBox(width: 10.w),
                          Flexible(
                              child: Container(
                                  padding: EdgeInsets.only(right: 13.0),
                                  width: MediaQuery.of(context).size.width *
                                      0.9,
                                  child: Text("settings_desc".tr(),
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20)))),
                          SizedBox(width: 10.w)
                        ]),
                        SizedBox(height: 20.h),
                        Row(children: [
                          SizedBox(width: 10.w),
                          Flexible(child: ScreenName(activeUser.givenName)),
                          SizedBox(width: 10.w),
                          Flexible(child: UILanguageSelector(true)),
                          SizedBox(width: 10.w)
                        ]),
                        SizedBox(height: 20.h),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [selfWidget]),
                        SizedBox(height: 20.h),
                        // Opacity(
                        // opacity: 0.3,
                        // child:
                        AudioMode(),
                        // ),
                        SizedBox(height: 10.h),
                        Row(children: [
                          SizedBox(width: 10.w),
                          Flexible(child: RoomSelector()),
                          SizedBox(width: 10.w),
                          Container(
                              height: 60.0,
                              child: ElevatedButton(
                                style: ButtonStyle(
                                  shape: MaterialStateProperty.all(RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.0)
                                  ))
                                ),
                                  // shape: RoundedRectangleBorder(
                                  //     borderRadius: BorderRadius.circular(10.0)
                                  // ),
                                  child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                            isThinScreen
                                                ? ''
                                                : 'join_room'.tr(),
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20)
                                        ),
                                        SizedBox(
                                            width: isThinScreen ? 0 : 10.w),
                                        HorizontalFlip(
                                          flipDirection: ui.TextDirection.rtl,
                                          child: Icon(
                                              Icons.double_arrow,
                                              color: Colors.white)
                                        )
                                      ]
                                  ),
                                  onPressed: () {
                                    final activeRoom = context.select(
                                            (MainStore s) => s.activeRoom);

                                    if (connectionStatus ==
                                        ConnectivityResult.none) {
                                      showDialog(
                                          context: context,
                                          builder: (BuildContext context){
                                          return AlertDialog(
                                              title: Text("No Internet"),
                                              content: Text(
                                                  "Please reconnect"));
                                      });
                                    } else if (activeRoom == null) {
                                      showDialog(
                                          context: context,
                                          builder:(BuildContext context){
                                            return AlertDialog(
                                              title:
                                              Text("Room not selected"),
                                              content: Text(
                                                  "Please select a room"));
                                      });
                                    } else {
                                      enterDashBoard(context);
                                    }
                                  })),
                          SizedBox(width: 10.w)
                        ]),
                        SizedBox(height: 20.h)
                      ])));
          SingleChildScrollView();
        }));
  }

  void enterDashBoard(BuildContext context) {
    selfWidget.stopCamera();
    Navigator.pushNamed(context, '/dashboard')
        .then((value) {
      if (value == false) {
        FlutterLogs.logInfo("Settings","pushNamed", "back from dashboard with failure");
        //need to fix crash after several re-enter
        // Timer(Duration(milliseconds: 1500),() {
           enterDashBoard(context);
        // }
        // );
      }
      else
        {
          selfWidget.unMute();
        }
      setState(() {
        selfWidget.restartCamera();
      });
    });
  }
}
