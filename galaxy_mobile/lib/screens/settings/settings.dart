import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/widgets/audioMode.dart';
import 'package:galaxy_mobile/widgets/roomSelector.dart';
import 'package:galaxy_mobile/widgets/screenLoader.dart';

import 'package:galaxy_mobile/widgets/screenName.dart';
import 'package:provider/provider.dart';

class Settings extends StatefulWidget {
  @override
  State createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    final activeUser = context.select((MainStore s) => s.activeUser);
    final rooms = context.select((MainStore s) => s.availableRooms);
    final activeRoom = context.select((MainStore s) => s.activeRoom);

    if ((activeUser == null) || (rooms == null)) {
      return ScreenLoader();
    } else {
      return Scaffold(
          appBar: AppBar(
            title: Text("Settings"),
          ),
          body: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            Text(
              "Hello ${activeUser.title}",
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
              "Please check your settings and device setup:",
              style: Theme.of(context).textTheme.headline6,
            ),

            ScreenName(activeUser.title),
            RoomSelector(),
            Text(activeRoom?.room.toString()), // Just for debug
            // Container(
            //   height: 200,
            //   width: 300,
            //   child: SelfViewWidget(),
            // ),
            AudioMode(),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/dashboard');
              },
              child: Text('Join Room'),
            )
          ]));
    }
  }
}
