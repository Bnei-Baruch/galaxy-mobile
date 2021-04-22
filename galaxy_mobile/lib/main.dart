import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/routes.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/themes/default.dart';
import 'package:provider/provider.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

import 'dart:io';
import 'package:archive/archive_io.dart';

import 'models/sharedPref.dart';


/* Compile notes:
- to generate luncher icons run:
flutter pub run flutter_launcher_icons:main

*/


void main() async {
   WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefs().init();

   //Initialize Logging
   await FlutterLogs.initLogs(
       logLevelsEnabled: [
         LogLevel.INFO,
         LogLevel.WARNING,
         LogLevel.ERROR,
         LogLevel.SEVERE
       ],
       timeStampFormat: TimeStampFormat.TIME_FORMAT_READABLE,
       directoryStructure: DirectoryStructure.FOR_DATE,
       logTypesEnabled: ["device","network","errors"],
       logFileExtension: LogFileExtension.LOG,
       logsWriteDirectoryName: "galaxyLogs",
       logsExportDirectoryName: "galaxyLogs/exported",
       debugFileOperations: true,
       isDebuggable: true);

   archiveLogs();

  runApp(
    /// Providers are above [MyApp] instead of inside it, so that tests
    /// can use [MyApp] while mocking the providers
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<Api>(create: (_) => Api()),
        ChangeNotifierProxyProvider2<AuthService, Api, MainStore>(
          create: (_) => MainStore(),
          update: (_, auth, api, model) => model..update(auth, api)
        ),
      ],
      child: MyApp()
    ),
  );
}

void archiveLogs() async {
  var encoder = ZipFileEncoder();
  encoder.create('/sdcard/Android/data/com.galaxy_mobile/files/galaxyLogs.zip');
  encoder.addDirectory(Directory('/sdcard/Android/data/com.galaxy_mobile/files/galaxyLogs'));
  encoder.close();

  final Email email = Email(
    body: 'body',
    subject: 'galaxy_logs',
    recipients: ['kirilsagoth2@gmail.com'],
    attachmentPaths: ['/sdcard/Android/data/com.galaxy_mobile/files/galaxyLogs.zip'],
    isHTML: false);

  await FlutterEmailSender.send(email);
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme(),
      initialRoute: '/',
      routes: routes,
    );
  }
}
