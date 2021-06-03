import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/widgets/connectedDots.dart';
import 'package:galaxy_mobile/widgets/uiLanguageSelector.dart';
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

class _LoginState extends State<Login> {
  bool _isThinScreen;

  Future<String> getFileData(String path) async {
    return await rootBundle.loadString(path);
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
    final authResponse = await auth.signIn();
    final api = context.read<Api>();
    api.setAccessToken(authResponse.accessToken);
    await context.read<MainStore>().init();
    Navigator.pushNamed(context, '/settings');
  }

  SingleChildScrollView getView(
      BuildContext context, BoxConstraints viewportConstraints) {
    if (_isThinScreen) {
      return SingleChildScrollView(
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: viewportConstraints.maxHeight),
              child: Container(
                  child: Column(children: [
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
                      SizedBox(width: 10.w)
                    ]),
                Row(children: [
                  SizedBox(width: 70.w),
                  Flexible(child: UILanguageSelector(false)),
                  SizedBox(width: 70.w)
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Column(children: [
                    SizedBox(height: 20),
                    Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(right: 13.0),
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: Text('registered_users'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 26,
                                fontWeight: FontWeight.bold))),
                    SizedBox(height: 20),
                    ButtonTheme(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0)),
                        minWidth: 140.0,
                        height: 60.0,
                        child: RaisedButton(
                            elevation: 5.0,
                            // color: Color(0xff0062b0),
                            highlightColor: Color(0xff00c6d2),
                            child: Text("login".tr(),
                                style: TextStyle(
                                    color: Colors.white, fontSize: 24)),
                            onPressed: () async { login(); }
                        )),
                    SizedBox(height: 20),
                    Container(
                        color: Colors.transparent,
                        width: MediaQuery.of(context).size.width * 0.8,
                        child:
                        ReadMoreText(
                            'login_desc'.tr(),
                            trimLines: 3,
                            colorClickableText: Color(0xff00c6d2),
                            trimMode: TrimMode.Line,
                            trimCollapsedText: 'Read more',
                            trimExpandedText: 'Read less',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white,
                                fontSize: 16),
                            lessStyle: TextStyle(color: Color(0xff00c6d2),
                                fontSize: 18),
                            moreStyle: TextStyle(color: Color(0xff00c6d2),
                                fontSize: 18))
                      // Text('login_desc'.tr(),
                      //     textAlign: TextAlign.center,
                      //     style: TextStyle(
                      //         color: Colors.white70, fontSize: 16))
                    ),
                    SizedBox(height: 20),
                    ButtonTheme(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            side: BorderSide(color: Colors.red, width: 1)),
                        minWidth: 140.0,
                        height: 60.0,
                        buttonColor: Colors.transparent,
                        child: RaisedButton(
                            child: Text("user_fee".tr(),
                                style:
                                    TextStyle(color: Colors.red, fontSize: 16)),
                            onPressed: () async {
                              const url = "https://kli.one/";
                              if (await canLaunch(url)) {
                                await launch(url);
                              } else {
                                FlutterLogs.logInfo("login", "pay fee button",
                                    "url $url invalid");
                              }
                            })),
                    SizedBox(height: 20),
                    InkWell(
                        child: new Text('t_and_c'.tr()),
                        onTap: () => showTAndCDialog(context)),
                    SizedBox(height: 20)
                  ])
                ])
              ]))));
    } else {
      return SingleChildScrollView(
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: viewportConstraints.maxHeight),
              child: Container(
                  child: Column(children: [
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
                                        color: Color(0xff00c6d2),
                                        fontSize: 16)),
                                Text('logo_text_2'.tr(),
                                    style: TextStyle(
                                        color: Color(0xff0062b0),
                                        fontSize: 16)),
                              ]),
                          SizedBox(width: 30.w),
                          Flexible(child: UILanguageSelector(false)),
                          SizedBox(width: 10.w)
                        ]),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Column(children: [
                        SizedBox(height: 20),
                        Container(
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(right: 13.0),
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: Text('registered_users'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold))),
                        SizedBox(height: 10),
                        ButtonTheme(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0)),
                            minWidth: 140.0,
                            height: 60.0,
                            child: Opacity(
                                opacity: 0.8,
                                child: RaisedButton(
                                elevation: 5.0,
                                // color: Color(0xff0062b0),
                                highlightColor: Color(0xff00c6d2),
                                child: Text("login".tr(),
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 24)),
                                onPressed: () async { login(); }
                                ))),
                        SizedBox(height: 20),
                        Container(
                            color: Colors.transparent,
                            width: MediaQuery.of(context).size.width * 0.8,
                            child:
                            ReadMoreText(
                                'login_desc'.tr(),
                                trimLines: 3,
                                colorClickableText: Color(0xff00c6d2),
                                trimMode: TrimMode.Line,
                                trimCollapsedText: 'Read more',
                                trimExpandedText: 'Read less',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white,
                                    fontSize: 16),
                                lessStyle: TextStyle(color: Color(0xff00c6d2),
                                    fontSize: 18),
                                moreStyle: TextStyle(color: Color(0xff00c6d2),
                                    fontSize: 18))
                            // Text('login_desc'.tr(),
                            //     textAlign: TextAlign.center,
                            //     style: TextStyle(
                            //         color: Colors.white70, fontSize: 16))
                        ),
                        SizedBox(height: 20),
                        ButtonTheme(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: BorderSide(color: Colors.red, width: 1)),
                            minWidth: 140.0,
                            height: 60.0,
                            buttonColor: Colors.transparent,
                            child: RaisedButton(
                                child: Text("user_fee".tr(),
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 16)),
                                onPressed: () async {
                                  const url = "https://kli.one/";
                                  if (await canLaunch(url)) {
                                    await launch(url);
                                  } else {
                                    FlutterLogs.logInfo("login",
                                        "pay fee button", "url $url invalid");
                                  }
                                })),
                        SizedBox(height: 20),
                        InkWell(
                            child: Text('t_and_c'.tr(),
                              style: TextStyle(
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              )),
                            onTap: () => showTAndCDialog(context)),
                        SizedBox(height: 20)
                      ])
                    ])
                  ]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    FlutterLogs.logInfo("main", "MyApp",
        "SCREEN WIDTH: ${MediaQuery.of(context).size.width.toString()}");
    _isThinScreen = MediaQuery.of(context).size.width < 400;
    return Scaffold(body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return Stack(children: <Widget>[
        ConnectedDots(),
        getView(context, viewportConstraints)
      ]);
    }));
  }
}
