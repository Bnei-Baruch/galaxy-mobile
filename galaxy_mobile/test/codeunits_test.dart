import 'dart:convert';

import 'package:flag/flag_enum.dart';
import 'package:flag/flag_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:mqtt5_client/mqtt5_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('code units test', () async {
    var units ="<123><34><111><110><108><105><110><101><34><58><32><116><114><117><101><125>";



  });

  test('flags units test', () async {

    var value = StreamConstants
        .audiog_options.firstWhere((element) => element.containsKey("flag") && element.values.contains("us"));

    var flag = Flag.fromCode(
        FlagsCode.values.firstWhere((e) => e.name == value["flag"].toString(),orElse: ()=> FlagsCode.IL),
        height: 24,
        width: 24,
        fit: BoxFit
            .contain);

    print(flag.countryCode);

  });
}
