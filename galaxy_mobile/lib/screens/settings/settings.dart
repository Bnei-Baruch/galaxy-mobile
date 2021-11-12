import 'dart:async';
import 'dart:isolate';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/logger.dart';
import 'package:galaxy_mobile/services/monitoring_isolate.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:galaxy_mobile/widgets/audioMode.dart';
import 'package:galaxy_mobile/widgets/drawer.dart';
import 'package:galaxy_mobile/widgets/loading_indicator.dart';
import 'package:galaxy_mobile/widgets/roomSelector.dart';
import 'package:galaxy_mobile/widgets/screenLoader.dart';
import 'package:galaxy_mobile/widgets/uiLanguageSelector.dart';

import 'package:provider/provider.dart';
import 'package:galaxy_mobile/widgets/screenName.dart';
import 'package:galaxy_mobile/widgets/selfViewWidget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final logger = new Logger("settings");

class Settings extends StatefulWidget {
  @override
  State createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with WidgetsBindingObserver {
  SelfViewWidget selfWidget;
  bool _isThinScreen;

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
      if(result  != ConnectivityResult.none && !mqttClient.isConnected())
        {
          mqttClient.connect();
        }
    });
    Utils.parseJson("user_monitor_example.json")
        .then((value) => userJsonExtra = value);
    Utils.parseJson("monitor_data.json").then((value) => monitorData = value);



    mqttClient.addOnDisconnectedCallback(()  {
      setState(() {

      });
    });
    mqttClient.addOnConnectedCallback(()  {
      if(dialogPleaseWaitContext!=null)
        Navigator.of(dialogPleaseWaitContext).pop();
      setState(() {

      });
    });
    mqttClient.addOnConnectionFailedCallback(() => {
      showDialog(
          context: context,
          builder: (context)  {
            dialogContext = context;
            return AlertDialog(
              title: new Text('Connection Message'),
              content: Text(
                  'Server is unreachable,\nplease make sure internet connection is available'),
              actions: <Widget>[
                new FlatButton(
                  onPressed: () {
                    Navigator.of(this.context, rootNavigator: true).pop();
                    mqttClient.connect();
                    // dismisses only the dialog and returns nothing
                  },
                  child: new Text('OK'),
                ),
              ],
            );
          }
      )
    });

    mqttClient.connect();
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
    var rooms = context.select((MainStore s) => s.availableRooms);

    // initIsolate(context).then((value) => {
    //       mainToIsolateStream = value,
    //       mainToIsolateStream.send({
    //         "type": 'setConnection',
    //         "user": activeUser,
    //         "userExtra": userJsonExtra,
    //         "data": monitorData
    //       }),
    //       mainToIsolateStream.send({"type": "start"})
    //     });
    // showDialog(
    //     context: context,
    //     useRootNavigator: false,
    //     barrierDismissible: false,
    //     builder: (BuildContext context) {
    //       dialogPleaseWaitContext = context;
    //       return WillPopScope(
    //           onWillPop: () {
    //             Navigator.of(dialogPleaseWaitContext).pop();
    //             return Future.value(true);
    //           },
    //           child: Dialog(
    //               backgroundColor: Colors.transparent,
    //               child: LoadingIndicator(
    //                   )));
    //     });
    _isThinScreen = MediaQuery.of(context).size.width < 400;
    final mqttClient = context.read<MQTTClient>();

    return (!mqttClient.isConnected())
        ? ScreenLoader()
        : Scaffold(
        appBar: AppBar(title: Text("settings".tr())),
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
                              child: RaisedButton(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10.0)),
                                  // label: _isThinScreen ? Text("") : Text(
                                  //     'join_room'.tr(),
                                  //     style: TextStyle(
                                  //         color: Colors.white,
                                  //         fontSize: 20)),
                                  child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Text(
                                            _isThinScreen
                                                ? ''
                                                : 'join_room'.tr(),
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20)),
                                        SizedBox(
                                            width:
                                            _isThinScreen ? 0 : 10.w),
                                        Icon(Icons.double_arrow,
                                            color: Colors.white)
                                      ]),
                                  onPressed: () {
                                    final activeRoom = context.select(
                                            (MainStore s) => s.activeRoom);

                                    if (connectionStatus ==
                                        ConnectivityResult.none) {
                                      showDialog(
                                          context: context,
                                          child: AlertDialog(
                                              title: Text("No Internet"),
                                              content: Text(
                                                  "Please reconnect")));
                                    } else if (activeRoom == null) {
                                      showDialog(
                                          context: context,
                                          child: AlertDialog(
                                              title:
                                              Text("Room not selected"),
                                              content: Text(
                                                  "Please select a room")));
                                    } else {
                                      selfWidget.stopCamera();
                                      Navigator.pushNamed(
                                          context,
                                          ''
                                              '/dashboard')
                                          .then((value) {
                                        if (value == false) {
                                          Navigator.pushNamed(
                                              context,
                                              ''
                                                  '/dashboard');
                                        }
                                        setState(() {
                                          selfWidget.restartCamera();
                                        });
                                      });
                                    }
                                  })),
                          SizedBox(width: 10.w)
                        ]),
                        SizedBox(height: 20.h)
                      ])));
          SingleChildScrollView();
        }));
  }
}

//
//
// (value as Dashboard).callReneter =
// () {
// FlutterLogs.logInfo("Settings", "callReneter", "executing");
// Navigator.pushNamed(
// context,
// ''
// '/dashboard');
// };
