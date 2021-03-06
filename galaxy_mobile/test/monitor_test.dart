import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}
