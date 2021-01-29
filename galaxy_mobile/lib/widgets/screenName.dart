import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:provider/provider.dart';

class ScreenName extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return FutureBuilder<User>(
        future: authService.getUser(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
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
