import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_plugin/flutter_foreground_plugin.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/routes.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/services/logger.dart';
import 'package:galaxy_mobile/themes/default.dart';
import 'package:provider/provider.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'models/sharedPref.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';

// Compile notes:
// - to generate luncher icons run:
// flutter pub run flutter_launcher_icons:main

final logger = new Logger("main");

Future<void> initLogs() async {
  await FlutterLogs.initLogs(
      logLevelsEnabled: [
        LogLevel.INFO,
        LogLevel.WARNING,
        LogLevel.ERROR,
        LogLevel.SEVERE
      ],
      timeStampFormat: TimeStampFormat.TIME_FORMAT_READABLE,
      directoryStructure: DirectoryStructure.FOR_DATE,
      logTypesEnabled: ["device", "network", "errors"],
      logFileExtension: LogFileExtension.LOG,
      logsWriteDirectoryName: "galaxy",
      logsExportDirectoryName: "galaxyLogs/exported",
      debugFileOperations: true,
      isDebuggable: true);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("main start");
  await SharedPrefs().init();
  await initLogs();
  print("main init logs passed");
  await Firebase.initializeApp();

  Wakelock.enable();
  await SentryFlutter.init(
          (options) {
        options.dsn = 'https://ac8b0f908e3c49d395c1fc47fb2022ca@sentry.kab.info/4';
      },
      appRunner: () => runApp(
    /// Providers are above [MyApp] instead of inside it, so that tests
    /// can use [MyApp] while mocking the providers
    MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => AuthService()),
          Provider<Api>(create: (_) => Api()),
          Provider<MQTTClient>(create: (_) => MQTTClient()),

          // Provider<Dashboard>(create: (_) => Dashboard()),
          ChangeNotifierProxyProvider3<AuthService, Api, MQTTClient, MainStore>(
              create: (_) => MainStore(),
              update: (_, auth, api, mqttClient, model) =>
              model..update(auth, api, mqttClient)),
        ],
        child: EasyLocalization(
            supportedLocales: [
              Locale('en', 'US'),
              Locale('ru', 'RU'),
              Locale('he', 'IL'),
              Locale('es', '')
            ],
            path: 'assets/translations',
            fallbackLocale: Locale('en', 'US'),
            child: MyApp())
      //MyApp()
    ),
  )
      );

}

class MyApp extends StatelessWidget with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance?.addObserver(this);
    return FGBGNotifier(
        onEvent: (event) {
          if (event == FGBGType.background) {
            FlutterLogs.logInfo(
                "MyApp", "FGBGNotifier", ">>> application sent to background");
            Wakelock.disable();
          } else if (event == FGBGType.foreground) {
            FlutterLogs.logInfo("MyApp", "FGBGNotifier",
                ">>> application returned to foreground");
            Wakelock.enable();
          }
        },
        child: ScreenUtilInit(
            designSize: Size(412, 732),
            allowFontScaling: false,
            builder: () => MaterialApp(
                debugShowCheckedModeBanner: false,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                theme: appTheme(),
                initialRoute: '/',
                routes: routes)));
  }
}
