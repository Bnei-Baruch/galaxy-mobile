import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:provider/provider.dart';

class Login extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Center(
        child: ElevatedButton(
          child: Text('Launch screen'),
          onPressed: () async {
            final result = await authService.signIn();

            final api = context.read<Api>();
            api.setAccessToken(result.accessToken);


             Navigator.pushNamed(context, '/settings');
          },
        ),
      ),
    );
  }
}
