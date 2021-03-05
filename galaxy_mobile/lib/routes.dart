import 'package:flutter/widgets.dart';
import 'package:galaxy_mobile/screens/dashboard/dashboard.dart';
import 'package:galaxy_mobile/screens/login/login.dart';
import 'package:galaxy_mobile/screens/settings/settings.dart';
import 'package:galaxy_mobile/screens/streaming/components/playerWIdget.dart';
import 'package:galaxy_mobile/screens/streaming/streaming.dart';
import 'package:galaxy_mobile/screens/video_room/videoRoomWidget.dart';

final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
  '/': (BuildContext context) => Login(),
  '/settings': (BuildContext context) => Settings(),
  '/dashboard': (BuildContext context) => Dashboard(),
  '/streaming': (BuildContext context) => StreamingUnified(),
  '/play_widget': (BuildContext context) => PlayerWidget(),
  '/roomWidget': (BuildContext context) => VideoRoom(),
};
