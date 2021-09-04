import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:logcat/logcat.dart';
import 'package:provider/provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info/package_info.dart';
import 'package:easy_localization/easy_localization.dart';

import 'dart:io';
import 'package:archive/archive_io.dart';

import 'package:path_provider/path_provider.dart';

// ignore: must_be_immutable
class AppDrawer extends StatelessWidget {
  void archiveLogs() async {
    FlutterLogs.logInfo("AppDrawer", "archiveLogs", "start");
    var encoder = ZipFileEncoder();

    var path = "";
    if (Platform.isAndroid) {
      path = "/sdcard/Android/data/com.galaxy_mobile/files";
    } else {
      path = ((await getApplicationSupportDirectory()).path);
    }
    FlutterLogs.logInfo("AppDrawer", "archiveLogs", "2");
    encoder.create(path + '/galaxyLogs.zip');
    FlutterLogs.logInfo(
        "AppDrawer", "archiveLogs", "2.0 zip path ${encoder.zip_path}");
    if (Platform.isAndroid) {
      File logcat = File(path + "/galaxyLogs/logcat.txt");
      final String logs = await Logcat.execute();

      if (!logcat.existsSync()) logcat.create();
      logcat.openWrite();
      logcat.writeAsStringSync(logs);
      encoder.addDirectory(Directory(path + '/galaxyLogs/'));
    }
    if (Platform.isIOS) {
      List<FileSystemEntity> list = Directory(path).listSync();
      FlutterLogs.logInfo("AppDrawer", "archiveLogs", "2.1 ${list.length} ");
      FlutterLogs.logInfo("AppDrawer", "archiveLogs",
          "2.2 ${list.map((value) => value.path.toString())}");
      encoder.addDirectory(Directory(path + "/Logs"));
    }
    FlutterLogs.logInfo("AppDrawer", "archiveLogs", "3 $path");
    FlutterLogs.logInfo("AppDrawer", "archiveLogs", "3.1");
    encoder.close();
    FlutterLogs.logInfo("AppDrawer", "archiveLogs", "4");
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String appName = packageInfo.appName;
    String packageName = packageInfo.packageName;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    FlutterLogs.logInfo("AppDrawer", "archiveLogs", "5");
    final Email email = Email(
        body:
            '<-------------please write above this line-----------> \n appName=${packageInfo.appName}\n packageName = ${packageInfo.packageName} \n version = ${packageInfo.version} \n buildNumber = ${packageInfo.buildNumber}',
        subject: 'Send logs to developer',
        recipients: ['igal.avraham@gmail.com'],
        attachmentPaths: [path + "/galaxyLogs.zip"],
        isHTML: false);
    FlutterLogs.logInfo("AppDrawer", "archiveLogs", "6");
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

  String version;
  AppDrawer({Key key}) : super(key: key) {
    PackageInfo.fromPlatform().then((value) => version = value.version);
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
            title: Text('my_account'.tr()),
            onTap: () {
              // Update the state of the app.
              // ...
            },
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('settings'.tr()),
            onTap: () async {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.email),
            title: Text('send_logs'.tr()),
            onTap: () async {
              archiveLogs();
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('sign_out'.tr()),
            onTap: () async {
              final auth = context.read<AuthService>();
              await auth.logout();
              Navigator.pushNamed(context, '/');
            },
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('version'.tr() + ": ${version}"),
          ),
        ],
      ),
    );
  }
}
