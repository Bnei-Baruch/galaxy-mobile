import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/widgets/audioMode.dart';
import 'package:galaxy_mobile/widgets/drawer.dart';
import 'package:galaxy_mobile/widgets/roomSelector.dart';
import 'package:galaxy_mobile/widgets/screenLoader.dart';

import 'package:galaxy_mobile/widgets/screenName.dart';
import 'package:galaxy_mobile/widgets/selfViewWidget.dart';
import 'package:provider/provider.dart';

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
            title: Text("Settings"),
          ),
          drawer: AppDrawer(),
          body: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            selfWidget,
            Text(
              "Hello ${activeUser.givenName}",
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
              "Please check your settings and device setup:",
              style: Theme.of(context).textTheme.headline6,
            ),

            ScreenName(activeUser.givenName),
            RoomSelector(),
            // Container(
            //   height: 200,
            //   width: 300,
            //   child: SelfViewWidget(),
            // ),
            AudioMode(),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/dashboard')
                    .then((value) => setState(() {
                          selfWidget.restartCamera();
                        }));
              },
              child: Text('Join Room'),
            )
          ]));
    }
  }
}
