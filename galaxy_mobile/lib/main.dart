import 'package:flutter/material.dart';
import 'package:galaxy_mobile/routes.dart';
import 'package:galaxy_mobile/themes/default.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme(),
      initialRoute: '/streaming',
      routes: routes,
    );
  }
}
