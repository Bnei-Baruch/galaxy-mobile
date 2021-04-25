import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child:
      Column(children: [
        Row(children: [
          SizedBox(width: 10),
          Image.asset('assets/graphics/logo_login.png',
              width: 70, fit: BoxFit.fill),
          SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 25),
                Text('our_connection'.tr(),
                    style: TextStyle(color: Color(0xff00c6d2), fontSize: 22)),
                Text('network'.tr(),
                    style: TextStyle(color: Color(0xff00457c), fontSize: 22)),
          ]),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(children: [
                SizedBox(height: 50),
                Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.only(right: 13.0),
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Text('registered_users'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black, fontSize: 26,
                            fontWeight: FontWeight.bold)
                    )
                ),
                SizedBox(height: 10),
                ButtonTheme(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    minWidth: 140.0,
                    height: 60.0,
                    child: RaisedButton(
                        child: Text("login".tr(),
                            style: TextStyle(color: Colors.white, fontSize: 24)),

                        onPressed: () async {
                          final auth = context.read<AuthService>();
                          final authResponse = await auth.signIn();
                          final api = context.read<Api>();
                          api.setAccessToken(authResponse.accessToken);
                          await context.read<MainStore>().init();
                          Navigator.pushNamed(context, '/settings');
                        })
                ),
              ])
            ]
        )])
      )
    );
  }
}
