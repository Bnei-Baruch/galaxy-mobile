import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:galaxy_mobile/services/monitoring_data.dart';
import 'package:galaxy_mobile/services/monitoring_isolate.dart';
import 'package:galaxy_mobile/utils/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prepare data test', () async {
    var user_monitor = await Utils.parseJson("user_monitor_example.json");
    var data_monitor = await Utils.parseJson("monitor_data.json");
    Map<String, dynamic> data_exp = {
      "user": user_monitor,
      "data": data_monitor
    };

    String data_to_send = json.encode(data_exp);
    print(data_to_send);
  });

  test('monitor on slow link test', () async {

    var data_monitor = await Utils.parseJson("monitor_data_mobile.json");
    MonitoringData(ReceivePort().sendPort).onSlowLink("receiving",6);
  });

  test('monitor on ice state test', () async {

    var data_monitor = await Utils.parseJson("monitor_data_mobile.json");
    MonitoringData(ReceivePort().sendPort).onIceState("connected");
  });

  test('monitor on getMisc test', () async {

    var data_monitor = await Utils.parseJson("monitor_data_mobile.json");
    var monitor = MonitoringData(ReceivePort().sendPort);
    monitor.onSlowLink("receiving",6);

    monitor.onIceState("connected");
    var misc = monitor.getMiscData(DateTime.now().millisecondsSinceEpoch);
    print(misc);
  });

  test('monitor on monitor test', () async {

    var data_monitor = await Utils.parseJson("monitor_data_mobile.json");
    var spec = await Utils.parseJson("whitelist.json");
    var monitor = MonitoringData(ReceivePort().sendPort);
    monitor.updateSpec(spec);
    monitor.onSlowLink("receiving",6);

    monitor.onIceState("connected");
    var misc = monitor.getMiscData(DateTime.now().millisecondsSinceEpoch);
    print(misc);
    monitor.monitor_(null);
  });
}
