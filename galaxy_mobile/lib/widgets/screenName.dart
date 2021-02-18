import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:provider/provider.dart';

typedef UserCallback = void Function(User user);

class ScreenName extends StatelessWidget {
  UserCallback gotUser;
  ScreenName(UserCallback callback) : gotUser = callback;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return FutureBuilder<User>(
        future: authService.getUser(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            gotUser(snapshot.data);
            return TextFormField(
                enabled: false,
                initialValue: snapshot.data.title,
                decoration: InputDecoration(
                  labelText: 'Screen Name',
                  // errorText: 'Error message'v          ,
                  border: OutlineInputBorder(),
                ));
            // return Text("snapshot.data");
          } else if (snapshot.hasError) {
            return Text("${snapshot.error}");
          }

          // By default, show a loading spinner.
          return CircularProgressIndicator();
        });
  }
}
