import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:logcat/logcat.dart';
import 'package:provider/provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info/package_info.dart';

import 'dart:io';
import 'package:archive/archive_io.dart';

class AppDrawer extends StatelessWidget {
  void archiveLogs() async {
    var encoder = ZipFileEncoder();
    encoder
        .create('/sdcard/Android/data/com.galaxy_mobile/files/galaxyLogs.zip');
    File logcat = File(
        '/sdcard/Android/data/com.galaxy_mobile/files/galaxyLogs/logcat.txt');
    final String logs = await Logcat.execute();

    if (!logcat.existsSync()) logcat.create();
    logcat.openWrite();
    logcat.writeAsString(logs);

    encoder.addDirectory(
        Directory('/sdcard/Android/data/com.galaxy_mobile/files/galaxyLogs'));

    encoder.close();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String appName = packageInfo.appName;
    String packageName = packageInfo.packageName;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;

    final Email email = Email(
        body:
            '<-------------please write above this line-----------> \n appName=${packageInfo.appName}\n packageName = ${packageInfo.packageName} \n version = ${packageInfo.version} \n buildNumber = ${packageInfo.buildNumber}',
        subject: 'Send logs to developer',
        recipients: ['igal.avraham@gmail.com'],
        attachmentPaths: [
          '/sdcard/Android/data/com.galaxy_mobile/files/galaxyLogs.zip'
        ],
        isHTML: false);

    await FlutterEmailSender.send(email);
    Fluttertoast.showToast(
        msg: "Logs sent to support",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 16.0);
  }

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
            leading: Icon(Icons.email),
            title: Text('Send Logs'),
            onTap: () async {
              archiveLogs();
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
