import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/authService.dart';
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

class Settings extends StatefulWidget {
  @override
  State createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  SelfViewWidget selfWidget;
  bool _isThinScreen;

  @override
  void initState() {
    super.initState();
    FlutterLogs.logInfo("Settings", "initState", "starting settings");
    selfWidget = SelfViewWidget();
  }

  SingleChildScrollView getView(BuildContext context,
      BoxConstraints viewportConstraints, User activeUser) {
    if (_isThinScreen) {
      return SingleChildScrollView(
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: viewportConstraints.maxHeight),
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
                              width: MediaQuery.of(context).size.width * 0.9,
                              child: Text(
                                  "hello_user"
                                      .tr(args: ['${activeUser.givenName}']),
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
                              width: MediaQuery.of(context).size.width * 0.9,
                              child: Text("settings_desc".tr(),
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20)))),
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
                      SizedBox(width: 70.w),
                      Flexible(child: RoomSelector()),
                      SizedBox(width: 70.w),
                    ]),
                    SizedBox(height: 10.h),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ButtonTheme(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0)),
                              minWidth: 140.0,
                              height: 60.0,
                              child: RaisedButton(
                                  child: Text("join_room".tr(),
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 20)),
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/dashboard')
                                        .then((value) => setState(() {
                                              selfWidget.restartCamera();
                                            }));
                                  })),
                        ]),
                    SizedBox(height: 30.h)
                  ])));
    } else {
      return SingleChildScrollView(
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: viewportConstraints.maxHeight),
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
                              width: MediaQuery.of(context).size.width * 0.9,
                              child: Text(
                                  "hello_user"
                                      .tr(args: ['${activeUser.givenName}']),
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
                              width: MediaQuery.of(context).size.width * 0.9,
                              child: Text("settings_desc".tr(),
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20)))),
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
                      ButtonTheme(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0)),
                          minWidth: 140.0,
                          height: 60.0,
                          child: RaisedButton(
                              child: Text("join_room".tr(),
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20)),
                              onPressed: () {
                                Navigator.pushNamed(context, '/dashboard')
                                    .then((value) => setState(() {
                                          selfWidget.restartCamera();
                                        }));
                              })),
                      SizedBox(width: 10.w)
                    ]),
                    SizedBox(height: 20.h)
                  ])));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = context.select((MainStore s) => s.activeUser);
    final rooms = context.select((MainStore s) => s.availableRooms);
    _isThinScreen = MediaQuery.of(context).size.width < 400;

    return (activeUser == null || rooms == null)
        ? ScreenLoader()
        : Scaffold(
            appBar: AppBar(title: Text("settings".tr())),
            drawer: AppDrawer(),
            body: LayoutBuilder(builder:
                (BuildContext context, BoxConstraints viewportConstraints) {
              return getView(context, viewportConstraints, activeUser);
              SingleChildScrollView();
            }));
  }
}
