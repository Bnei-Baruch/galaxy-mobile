import 'package:flutter/material.dart';

class Participant extends StatefulWidget {
  @override
  _ParticipantState createState() => _ParticipantState();
}

class _ParticipantState extends State<Participant> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
        child: Container(
            child: Placeholder(),
            color: Colors.orange),
        fit: BoxFit.fill);
  }
}
