import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/widgets/audioMode.dart';
import 'package:galaxy_mobile/widgets/roomSelector.dart';

import 'package:galaxy_mobile/widgets/screenName.dart';

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Settings"),
        ),
        body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ScreenName(),
          RoomSelector(),
          AudioMode(),
          ElevatedButton(
            onPressed: () {
              // Respond to button press
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
}
