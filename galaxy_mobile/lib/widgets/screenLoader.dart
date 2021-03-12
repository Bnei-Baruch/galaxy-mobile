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
            Image.asset('assets/graphics/logo.png', fit: BoxFit.contain),
            LinearProgressIndicator(),
            Text("loading"),
          ],
        )));
  }
}
