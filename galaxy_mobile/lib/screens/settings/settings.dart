import 'dart:async';
import 'dart:isolate';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/logger.dart';
import 'package:galaxy_mobile/services/monitoring_isolate.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:galaxy_mobile/widgets/audioMode.dart';
import 'package:galaxy_mobile/widgets/drawer.dart';
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

class _SettingsState extends State<Settings> {
  SelfViewWidget selfWidget;
  bool _isThinScreen;

  StreamSubscription<ConnectivityResult> subscription;

  ConnectivityResult connectionStatus;

  SendPort mainToIsolateStream;

  var userJsonExtra;

  var monitorData;

  @override
  Future<void> initState() {
    super.initState();
    logger.info("starting settings");
    selfWidget = SelfViewWidget();

    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      connectionStatus = result;
    });
    Utils.parseJson("user_monitor_example.json")
        .then((value) => userJsonExtra = value);
    Utils.parseJson("monitor_data.json").then((value) => monitorData = value);
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = context.select((MainStore s) => s.activeUser);
    final rooms = context.select((MainStore s) => s.availableRooms);

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

    _isThinScreen = MediaQuery.of(context).size.width < 400;

    return (activeUser == null || rooms == null)
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
                            Opacity(
                              opacity: 0.3,
                              child: AudioMode(),
                            ),
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
                                        final activeRoom =
                                        context.select((MainStore s) =>
                                        s.activeRoom);

                                        if (connectionStatus ==
                                            ConnectivityResult.none)
                                        {
                                          showDialog(
                                              context: context,
                                              child: AlertDialog(
                                                title: Text("No Internet"),
                                                content:
                                                    Text("Please reconnect")
                                              ));
                                        } else if (activeRoom == null) {
                                          showDialog(
                                              context: context,
                                              child: AlertDialog(
                                                title:
                                                Text("Room not selected"),
                                                content:
                                                Text("Please select a room")
                                              ));
                                        } else {
                                          selfWidget.stopCamera();
                                          Navigator.pushNamed(
                                                  context, ''
                                                  '/dashboard')
                                              .then((value) {
                                            if (value == false) {
                                              Navigator.pushNamed(
                                                  context, ''
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
