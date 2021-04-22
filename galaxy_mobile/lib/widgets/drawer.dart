import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final activeUser = context.select((MainStore s) => s.activeUser);

    return Drawer(
      // Add a List View to the drawer. This ensures the user can scroll
      // through the options in the drawer if there isn't enough vertical
      // space to fit everything.
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
          ListTile(
            leading: Icon(Icons.home),
            title: Text('My Account'),
            onTap: () {
              // Update the state of the app.
              // ...
            },
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Settings'),
            onTap: () async {
              Navigator.pushNamed(context, '/settings');

            },
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Sign Out'),
            onTap: () async {
              final auth = context.read<AuthService>();
              await auth.logout();
              Navigator.pushNamed(context, '/');

            },
          ),
        ],
      ),
    );
  }
}
