import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/screens/streaming/streaming.dart';
import 'package:galaxy_mobile/screens/video_room/videoRoomWidget.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:provider/provider.dart';

import '../../services/authService.dart';

class Dashboard extends StatefulWidget {
  bool audioMute = true;
  bool videoMute = true;

  @override
  State createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  var stream = StreamingUnified();
  var videoRoom = VideoRoom();

  MQTTClient _mqttClient;

  String _activeRoomId;

  @override
  void initState() {
    // TODO: implement initState
    widget.audioMute = true;
    widget.videoMute = true;
  }

  void handleCmdData(String msgPayload) {
    FlutterLogs.logInfo("Dashboard", "handleCmdData", "Received message: $msgPayload");
    var jsonCmd = JsonDecoder().convert(msgPayload);
    switch (jsonCmd["type"]) {
      case "client-state":
        videoRoom.setUserState(jsonCmd["data"]["user"]);
        break;
    }
  }

  void connectedToBroker() {
    _mqttClient.subscribe("galaxy/room/" + _activeRoomId);
  }

  @override
  Widget build(BuildContext context) {
    final activeRoom = context.select((MainStore s) => s.activeRoom);
    final authService = context.read<AuthService>();
    final activeUser = context.select((MainStore s) => s.activeUser);

    _activeRoomId = activeRoom.room.toString();

    if (_mqttClient == null) {
      _mqttClient = MQTTClient(authService.getUserEmail(),
          authService.getAuthToken(),
          this.handleCmdData, this.connectedToBroker);
      _mqttClient.connect();
      // _mqttClient.subscribe('galaxy/users/broadcast');
    }

    return WillPopScope(
      onWillPop: () {
        Navigator.of(context).pop(true);
        stream.exit();
        videoRoom.exitRoom();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(activeRoom.description),
        ),
        // body: FittedBox(
        //     child: Container(child: Placeholder(), color: Colors.green),
        //     fit: BoxFit.fill),
        body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [stream, videoRoom]),
        bottomNavigationBar: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                // IconButton()
                icon: widget.audioMute
                    ? Icon(
                        Icons.mic_off,
                        color: Colors.red,
                      )
                    : Icon(
                        Icons.mic,
                        color: Colors.white,
                      ),
                label: "Mic"),
            BottomNavigationBarItem(
                icon: widget.videoMute
                    ? Icon(
                        Icons.videocam_off,
                        color: Colors.red,
                      )
                    : Icon(Icons.videocam),
                label: "Video"),
            BottomNavigationBarItem(
              icon: Icon(Icons.live_help),
              label: 'Ask Question',
            ),
          ],
          // currentIndex: _selectedIndex,
          // selectedItemColor: Colors.amber[800],
          onTap: (value) {
            //only for debugging purposes
            FlutterLogs.logInfo("Dashboard", "onTap", value.toString());
            switch (value) {
              case 0:
                videoRoom.mute();
                setState(() {
                  widget.audioMute = !widget.audioMute;
                });

                break;
              case 1:
                videoRoom.toggleVideo();
                setState(() {
                  widget.videoMute = !widget.videoMute;
                });
                String msg =
                    "{"
                        "type: client-state, "
                        "user: " + activeUser.toString() +
                    "}";
                _mqttClient.send("galaxy/room/" + _activeRoomId, msg);
                break;
            }
          },
        ),
      ),
    );
  }
}

//         drawer: Drawer(
//   // Add a List View to the drawer. This ensures the user can scroll
//   // through the options in the drawer if there isn't enough vertical
//   // space to fit everything.
//   child: ListView(
//     // Important: Remove any padding from the ListView.
//     padding: EdgeInsets.zero,
//     children: <Widget>[
//       DrawerHeader(
//         child: Text('Drawer Header'),
//         decoration: BoxDecoration(
//           color: Colors.blue,
//         ),
//       ),
//       ListTile(
//         leading: Icon(Icons.home),
//         title: Text('My Account'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//       ListTile(
//         title: Text('Settings'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//       ListTile(
//         title: Text('Sign out'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//       Divider(),
//       ListTile(
//         title: Text('Feedback'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//       ListTile(
//         title: Text('Help'),
//         onTap: () {
//           // Update the state of the app.
//           // ...
//         },
//       ),
//     ],
//   ),
// ),
