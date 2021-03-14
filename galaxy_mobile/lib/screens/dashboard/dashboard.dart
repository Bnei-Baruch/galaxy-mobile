import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/screens/streaming/streaming.dart';
import 'package:galaxy_mobile/screens/video_room/videoRoomWidget.dart';
import 'package:provider/provider.dart';

class Dashboard extends StatefulWidget {
  @override
  State createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  var stream = StreamingUnified();
  var videoRoom = VideoRoom();
  @override
  void initState() {
    // TODO: implement initState
  }
  @override
  Widget build(BuildContext context) {
    final activeRoom = context.select((MainStore s) => s.activeRoom);

    return Scaffold(
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            // IconButton()
            icon: Icon(Icons.mic),
            label: 'Mute',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: 'Stop Video',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.live_help),
            label: 'Ask Question',
          ),
        ],
        // currentIndex: _selectedIndex,
        // selectedItemColor: Colors.amber[800],
        onTap: (value) {
          //only for debugging purposes
          print(value);
          switch (value) {
            case 0:
              videoRoom.exitRoom();
              break;
            case 1:
              stream.exit();
              break;
          }
        },
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
