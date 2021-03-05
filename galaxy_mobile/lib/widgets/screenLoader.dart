import 'package:flutter/material.dart';


class ScreenLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
        widthFactor: 0.5,
        heightFactor: 0.5,
        child: Center(
            child: Column(
          children: [
            Image.asset('lib/assets/images/logo.png', fit: BoxFit.contain),
            LinearProgressIndicator(),
            Text("loading"),
          ],
        )));
  }
}
