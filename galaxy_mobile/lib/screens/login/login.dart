import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:provider/provider.dart';

class Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Center(
          child: Column(children: [
        ElevatedButton(
          child: Text('Launch screen'),
          onPressed: () async {
            final auth = context.read<AuthService>();
            final authResponse = await auth.signIn();

            final api = context.read<Api>();
            api.setAccessToken(authResponse.accessToken);

            context.read<MainStore>()
              ..fetchUser()
              ..fetchConfig()
              ..fetchAvailableRooms(false);

             Navigator.pushNamed(context, '/settings');
          },
        ),
      ),
      ])),
    );
  }
}
