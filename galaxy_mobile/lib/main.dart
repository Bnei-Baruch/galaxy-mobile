import 'package:flutter/material.dart';
import 'package:flutter_foreground_plugin/flutter_foreground_plugin.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/routes.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/themes/default.dart';
import 'package:provider/provider.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'models/sharedPref.dart';
import 'package:easy_localization/easy_localization.dart';

// Compile notes:
// - to generate luncher icons run:
// flutter pub run flutter_launcher_icons:main

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefs().init();
  // await EasyLocalization.ensureInitialized();
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
      logsWriteDirectoryName: "galaxyLogs",
      logsExportDirectoryName: "galaxyLogs/exported",
      debugFileOperations: true,
      isDebuggable: true);

  runApp(
    /// Providers are above [MyApp] instead of inside it, so that tests
    /// can use [MyApp] while mocking the providers
    MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => AuthService()),
          Provider<Api>(create: (_) => Api()),
          ChangeNotifierProxyProvider2<AuthService, Api, MainStore>(
              create: (_) => MainStore(),
              update: (_, auth, api, model) => model..update(auth, api)),
        ],
        child: EasyLocalization(
            supportedLocales: [Locale('en', 'US'), Locale('ru', 'RU')],
            path: 'assets/translations',
            fallbackLocale: Locale('en', 'US'),
            child: MyApp())
        //MyApp()
        ),
  );
}

void startForegroundService() async {
  await FlutterForegroundPlugin.setServiceMethodInterval(seconds: 5);
  await FlutterForegroundPlugin.setServiceMethod(globalForegroundService);
  await FlutterForegroundPlugin.startForegroundService(
    holdWakeLock: false,
    onStarted: () {
      print("Foreground on Started");
    },
    onStopped: () {
      print("Foreground on Stopped");
    },
    title: "Flutter Foreground Service",
    content: "This is Content",
    iconName: "ic_stat_hot_tub",
  );
}

void stopForegroundService() async {
  await FlutterForegroundPlugin.stopForegroundService();
}

void globalForegroundService() {
  debugPrint("current datetime is ${DateTime.now()}");
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
        designSize: Size(412, 732),
        allowFontScaling: false,
        builder: () => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: appTheme(),
              initialRoute: '/',
              routes: routes,
            )
    );
  }
}
