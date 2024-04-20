import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_version_checker/flutter_app_version_checker.dart';
import 'package:flutter_appauth_platform_interface/src/token_response.dart';
import 'package:galaxy_mobile/models/main_store.dart';
import 'package:galaxy_mobile/models/shared_pref.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/auth_service.dart';
import 'package:galaxy_mobile/services/mqtt_client.dart';
import 'package:galaxy_mobile/widgets/connected_dots.dart';
import 'package:galaxy_mobile/widgets/ui_language_selector.dart';
import 'package:new_version/new_version.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:readmore/readmore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter/services.dart' show rootBundle;

class Login extends StatefulWidget {
  @override
  State createState() => _LoginState();
}

class _LoginState extends State<Login>  with WidgetsBindingObserver {
  Timer refresher;
  var newVersion;

  final _versionChecker = AppVersionChecker(
    appId: "com.galaxy_mobile",
    androidStore: AndroidStore.googlePlayStore,

  );

  String snapValue;
  String versionValue;

  Future<String> getFileData(String path) async {
    return await rootBundle.loadString(path);
  }

  @override
  initState() {
     checkVersion();
     newVersion = NewVersion(
        iOSId: 'com.galaxy.mobile',
        androidId: 'com.galaxy_mobile',
       // context: context
    );
    WidgetsBinding.instance.addObserver(this);
    advancedStatusCheck(newVersion);
  }

  void checkVersion() async {
    await Future.wait([

      _versionChecker
          .checkUpdate()
          .then((value) => versionValue = value.toString()),
    ]);

    setState(() {
      setState(() {
        FlutterLogs.logInfo("Login", "version", "version is $versionValue");
      });
    });
  }
  basicStatusCheck(NewVersion newVersion) {
    newVersion.showAlertIfNecessary();
  }

  advancedStatusCheck(NewVersion newVersion) async {
    final status = await newVersion.getVersionStatus();
    if (status != null) {
      debugPrint(status.appStoreLink);
      debugPrint(status.localVersion);
      debugPrint(status.storeVersion);
      debugPrint(status.canUpdate.toString());
      int localVersion = int.parse(status.localVersion.replaceAll(".",""));
      int storeVersion = int.parse(status.storeVersion.replaceAll(".",""));
      if (isVersionGreaterThan(status.storeVersion,status.localVersion))
        newVersion.showUpdateDialog();
    }
  }

  bool isVersionGreaterThan(String newVersion, String currentVersion){
    List<String> currentV = currentVersion.split(".");
    List<String> newV = newVersion.split(".");
    bool a = false;
    for (var i = 0 ; i <= 2; i++){
      a = int.parse(newV[i]) > int.parse(currentV[i]);
      if(int.parse(newV[i]) != int.parse(currentV[i])) break;
    }
    return a;
  }
  Future<void> showTAndCDialog(BuildContext context) async {
    String tAndCText = await getFileData('assets/res/t_and_c_'
        '${EasyLocalization.of(context).locale.languageCode}.txt');

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('terms_of_use'.tr()),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[Text(tAndCText)],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('close'.tr()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void login() async {
    final auth = context.read<AuthService>();
    final store = context.read<MainStore>();
    if(store.getLastLogin().isAfter(DateTime.now().subtract(Duration(hours: 21))))
      {
        if(Platform.isIOS)
          {
            var supportDir = await getApplicationSupportDirectory();
            Directory logsDir = Directory(supportDir.path+"/Logs");
            logsDir.deleteSync(recursive: true);
            logsDir.create();
          }
        else
          {
            var supportDir = await getExternalStorageDirectories();
            FlutterLogs.logInfo("login", "logs", "supportDir= $supportDir");

             Directory logsDir = Directory(supportDir[0].path+"/galaxy/Logs");
            logsDir.deleteSync(recursive: true);
            logsDir.create();
          }
      }
    final api = context.read<Api>();
    var authResponse = await auth.signIn();

    if (refresher != null) {
      refresher.cancel();
    }

    refreshTimer(authResponse, auth, api);
    print("access token ${authResponse.accessToken} ");
    print("refresh time=${authResponse.accessTokenExpirationDateTime.toIso8601String()}");
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    store.version = packageInfo.version;

    api.setAccessToken(authResponse.accessToken);

    await context.read<MainStore>().init();
    if (!context.read<MainStore>().activeUser.roles.contains("gxy_user")) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("User Permission"),
              content: Text("Not Allowed"),
          );
        });
    } else {
      store.setLastLogin(DateTime.now());

      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,Permission.bluetoothConnect
      ].request();
      print("permission status: ${statuses[Permission.bluetooth]}  and ${statuses[Permission.bluetoothConnect]}");


     Navigator.pushNamed(context, '/settings');
    }
  }

  void refreshTimer(TokenResponse authResponse, AuthService auth, Api api) {
    FlutterLogs.logInfo("login", "refreshTimer", "refresh request time=${authResponse.accessTokenExpirationDateTime.toIso8601String()}");
     refresher = Timer(Duration(milliseconds: authResponse.accessTokenExpirationDateTime.millisecondsSinceEpoch-DateTime.now().millisecondsSinceEpoch), () async {
      FlutterLogs.logInfo("login", "refreshTimer", "refresh execution ");
      authResponse = await auth.refreshToken();
      api.setAccessToken(authResponse.accessToken);
      var mqttClient = context.read<MQTTClient>();
      mqttClient.updateToken(authResponse.accessToken);
      refreshTimer(authResponse, auth, api);
    });
  }

  Container getView(BuildContext context, BoxConstraints viewportConstraints) {
    return Container(
        alignment: Alignment.topCenter,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(height: 20),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 10),
                    Image.asset('assets/graphics/logo_login.png',
                        width: 50, fit: BoxFit.fill),
                    SizedBox(width: 8),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 25),
                          Text('logo_text_1'.tr(),
                              style: TextStyle(
                                  color: Color(0xff00c6d2), fontSize: 16)),
                          Text('logo_text_2'.tr(),
                              style: TextStyle(
                                  color: Color(0xff0062b0), fontSize: 16)),
                        ]),
                    SizedBox(width: 30.w),
                    Spacer(),
                    Container(
                      child: UILanguageSelector(false),
                      width: 120,
                    ),
                    SizedBox(width: 10.w)
                  ]),
              Text('registered_users'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 36,
                      fontWeight: FontWeight.bold)),
              Padding(
                padding: EdgeInsets.only(bottom: 50, top: 20),
                child: ReadMoreText('login_desc'.tr(),
                    trimLines: 3,
                    colorClickableText: Color(0xff00c6d2),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22)),
                // Text('login_desc'.tr(),
                //     textAlign: TextAlign.center,
                //     style: TextStyle(
                //         color: Colors.white70, fontSize: 16))
              ),
              SizedBox(height: 20),
              ButtonTheme(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0)),
                  minWidth: 140.0,
                  height: 60.0,
                  child: Opacity(
                      opacity: 0.8,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          elevation: MaterialStateProperty.all(5),
                          foregroundColor: MaterialStateProperty.all(Color(0xff00c6d2))
                        ),
                          // elevation: 5.0,
                          // // color: Color(0xff0062b0),
                          // highlightColor: Color(0xff00c6d2),
                          child: Text("login".tr(),
                              style:
                                  TextStyle(color: Colors.white, fontSize: 24)),
                          onPressed: () async {
                            login();
                          }))),
              Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: 50),
                child: InkWell(
                    child: Text('t_and_c'.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          decoration: TextDecoration.underline,
                        )),
                    onTap: () => showTAndCDialog(context)),
              )
            ]));
  }

  @override
  Widget build(BuildContext context) {
    FlutterLogs.logInfo("login", "MyApp",
        "SCREEN WIDTH: ${MediaQuery.of(context).size.width.toString()}");
    return Scaffold(body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return Stack(children: <Widget>[
        ConnectedDots(),
        getView(context, viewportConstraints)
      ]);
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
        FlutterLogs.logInfo("login", "appLifeCycleState", "inactive");

        break;
      case AppLifecycleState.resumed:
        FlutterLogs.logInfo("login", "appLifeCycleState", "resumed");
       advancedStatusCheck(newVersion);
        break;
      case AppLifecycleState.paused:
        FlutterLogs.logInfo("login", "appLifeCycleState", "paused");

        break;
      case AppLifecycleState.detached:
        FlutterLogs.logInfo("login", "appLifeCycleState", "detached");

        break;
    }
  }
}
