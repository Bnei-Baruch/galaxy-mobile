import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/widgets/audioMode.dart';
import 'package:galaxy_mobile/widgets/drawer.dart';
import 'package:galaxy_mobile/widgets/roomSelector.dart';
import 'package:galaxy_mobile/widgets/screenLoader.dart';
import 'package:galaxy_mobile/widgets/uiLanguageSelector.dart';

import 'package:flutter_logs/flutter_logs.dart';
import 'package:provider/provider.dart';
import 'package:galaxy_mobile/widgets/screenName.dart';
import 'package:galaxy_mobile/widgets/selfViewWidget.dart';
import 'package:easy_localization/easy_localization.dart';

class Settings extends StatefulWidget {
  @override
  State createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  SelfViewWidget selfWidget;
  @override
  void initState() {
    super.initState();
    FlutterLogs.logInfo("Settings", "initState", "starting settings");
    selfWidget = SelfViewWidget();
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = context.select((MainStore s) => s.activeUser);
    final rooms = context.select((MainStore s) => s.availableRooms);

    if ((activeUser == null) || (rooms == null)) {
      return ScreenLoader();
    } else {
      return Scaffold(
          appBar: AppBar(
            title: Text("settings".tr()),
          ),
          drawer: AppDrawer(),
          body: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Row(children: [
                  SizedBox(width: 10),
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
                  SizedBox(width: 10)
                ]),
                SizedBox(height: 10),
                Row(children: [
                  SizedBox(width: 10),
                  Flexible(
                      child: Container(
                          padding: EdgeInsets.only(right: 13.0),
                          width: MediaQuery.of(context).size.width * 0.9,
                          child: Text("settings_desc".tr(),
                              style: TextStyle(
                                  color: Colors.white, fontSize: 20)))),
                  SizedBox(width: 10)
                ]),
                SizedBox(height: 20),
                Row(children: [
                  SizedBox(width: 10),
                  Flexible(child: ScreenName(activeUser.givenName)),
                  SizedBox(width: 10),
                  Flexible(child: UILanguageSelector()),
                  SizedBox(width: 10)
                ]),
                SizedBox(height: 20),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [selfWidget]),
                SizedBox(height: 20),
                AudioMode(),
                SizedBox(height: 10),
                Row(children: [
                  SizedBox(width: 10),
                  Flexible(child: RoomSelector()),
                  SizedBox(width: 10),
                  ButtonTheme(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                      minWidth: 140.0,
                      height: 60.0,
                      child: RaisedButton(
                          child: Text("join_room".tr(),
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20)),
                          onPressed: () {
                            Navigator.pushNamed(context, '/dashboard')
                                .then((value) => setState(() {
                                      selfWidget.restartCamera();
                                    }));
                          })),
                  SizedBox(width: 10)
                ]),
              ]));
    }
  }
}
