import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/authService.dart';

typedef UserCallback = void Function(User user);

class ScreenName extends StatelessWidget {
  final name;
  ScreenName(this.name);

  @override
  Widget build(BuildContext context) {

    return TextFormField(
        enabled: false,
        initialValue: name,
        decoration: InputDecoration(
          labelText: 'Screen Name',
          // errorText: 'Error message'v          ,
          border: OutlineInputBorder(),
        ));
  }
}
