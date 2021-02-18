import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/screens/video_room/videoRoomWidget.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/widgets/audioMode.dart';
import 'package:galaxy_mobile/widgets/roomSelector.dart';

import 'package:galaxy_mobile/widgets/screenName.dart';
import 'package:provider/provider.dart';

class Settings extends StatefulWidget {
  @override
  State createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Future<List<RoomData>> config;
  int roomNumber;
  String server;
  String serverUrl;
  String token;

  User user;
  @override
  void initState() {
    super.initState();
    final api = Provider.of<Api>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    config = api.fetchConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Settings"),
        ),
        body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ScreenName((User) => {user = User}),
          RoomSelector((int room, String serverName) =>
              {roomNumber = room, server = serverName, lookUpDataForRoom()}),
          AudioMode(),
          ElevatedButton(
            onPressed: () {
              // Respond to button press
              Navigator.pushNamed(context, '/roomWidget',
                  arguments: RoomArguments(serverUrl, token, roomNumber, user));
            },
            child: Text('Join Room'),
          )
        ]

            //  ElevatedButton(
            //     onPressed: () {
            //       // Navigate back to first screen when tapped.
            //          Navigator.pop(context);
            //     },
            //     child: Text('Go back!'),
            // ),
            ));
  }

  lookUpDataForRoom() {
    RoomData element;
    config.then((list) => {
          element = list.firstWhere((element) => element.name == server),
          serverUrl = element.url,
          token = element.token
        });
    //  print(token);
    //value[server]["url"].
  }
}
