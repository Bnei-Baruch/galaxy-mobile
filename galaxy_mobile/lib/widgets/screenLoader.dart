import 'package:flutter/material.dart';


class ScreenLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return
      Container(
        color: Colors.black,
        child:FractionallySizedBox(
        widthFactor: 0.5,
        heightFactor: 0.5,
        child: Center(
            child: Column(
          children: [
            Image.asset('assets/graphics/logo.png', fit: BoxFit.contain),
            LinearProgressIndicator(),
            FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text('Please Wait')
              ),
          ],
        ))));
  }
}
