import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Room extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Room Name"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigate back to first screen when tapped.
            Navigator.pop(context);
          },
          child: Text('Go back!'),
        ),
      ),
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
        // onTap: _onItemTapped,
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
