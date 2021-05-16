import 'package:flutter_foreground_plugin/flutter_foreground_plugin.dart';
import 'package:galaxy_mobile/services/logger.dart';

final logger = new Logger("ForgroundService");

void startForegroundService() async {
  await FlutterForegroundPlugin.setServiceMethodInterval(seconds: 5);
  await FlutterForegroundPlugin.setServiceMethod(globalForegroundService);
  await FlutterForegroundPlugin.startForegroundService(
      holdWakeLock: false,
      // keepRunning: true,
      onStarted: () {
        logger.info("foreground service started");
      },
      onStopped: () {
        logger.info("foreground service stopped");
      },
      title: "Arvut Mobile",
      content: "Playing in the background",
      iconName: "ic_launcher_foreground");
}

void stopForegroundService() async {
  await FlutterForegroundPlugin.stopForegroundService();
}

void globalForegroundService() {
  logger.info("current datetime is ${DateTime.now()}");
}
