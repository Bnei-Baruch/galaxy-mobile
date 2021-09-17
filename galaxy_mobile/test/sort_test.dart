import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:galaxy_mobile/utils/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sort data test', () async {
    var publishers = await Utils.parseJson("publishers.json");

    print(publishers);
    publishers = Utils.sortAndFilterFeeds(publishers);
    print(publishers);
  });
}
