import 'package:flutter/material.dart';

class Participants extends StatefulWidget {
  @override
  _ParticipantsState createState() => _ParticipantsState();
}

class _ParticipantsState extends State<Participants> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
        child: Container(
            child: Placeholder(),
            color: Colors.yellow),
        fit: BoxFit.fill);
  }
}
