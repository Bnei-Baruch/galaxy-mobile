import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:galaxy_mobile/utils/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prepare data test', () async {
    var user_data = await Utils.parseJson("user_update.json");

    print(user_data);
  });
}
