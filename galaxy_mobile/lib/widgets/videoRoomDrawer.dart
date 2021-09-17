import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class VideoRoomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final activeUser = context.select((MainStore s) => s.activeUser);

    return Drawer(
        child: ListView(
            // Important: Remove any padding from the ListView.
            padding: EdgeInsets.zero,
            children: <Widget>[
          DrawerHeader(
            child: Text(activeUser.name),
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
          ),
          // ListTile(
          //   leading: Icon(Icons.chat),
          //   title: Text('chat'.tr()),
          //   onTap: () {
          //     Navigator.pushNamed(context, '/chat');
          //   },
          // )
        ]));
  }
}
