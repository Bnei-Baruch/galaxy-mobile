import 'package:flutter/material.dart';

class Broadcast extends StatefulWidget {
  @override
  _BroadcastState createState() => _BroadcastState();
}

class _BroadcastState extends State<Broadcast> {
  @override
  Widget build(BuildContext context) {
    return FittedBox(
        child: Container(
            child: Placeholder(),
            color: Colors.green),
        fit: BoxFit.fill);
  }
}
