import 'package:flutter/widgets.dart';
import 'package:galaxy_mobile/screens/login/login.dart';
import 'package:galaxy_mobile/screens/room/room.dart';
import 'package:galaxy_mobile/screens/settings/settings.dart';

final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
  '/': (BuildContext context) => Login(),
  '/room': (BuildContext context) => Room(),
  '/settings': (BuildContext context) => Settings(),
};
