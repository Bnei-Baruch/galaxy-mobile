import 'dart:collection';
import 'dart:convert';

import 'package:flag/flag_enum.dart';
import 'package:flag/flag_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';
import 'package:galaxy_mobile/screens/streaming/constants.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:sdp_transform/sdp_transform.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parse sdp', () async {
    String sdp = await Utils.parseTxt("sdp_example.txt");

    var res = sdp.contains("profile-level-id=42e01f");
    int start = sdp.indexOf("profile-level-id=42e01f");
    sdp = sdp.replaceRange(start,start+"profile-level-id=42e01f".length,"profile-level-id=111111");
    var sdp_map = parse(sdp);
    var result = sdp_map.containsValue("level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f");
    print(sdp_map);
   // var matches = sdp.repl(";profile-level-id");
  });

  test('parse bad sdp', () async {
    String sdp = await Utils.parseTxt("sdp_bad.txt");
    const splitter = LineSplitter();
    // var res = sdp.contains("profile-level-id=42e01f");
    // int start = sdp.indexOf("profile-level-id=42e01f");
    // sdp = sdp.replaceRange(start,start+"profile-level-id=42e01f".length,"profile-level-id=111111");
    var sdp_map = parse(sdp.toString());
    var medias = sdp_map["media"];
    medias.forEach((element) {

      if(element["type"] == "video")
        {
          if((element["fmtp"] as List).isEmpty)
            {
              var payload = LinkedHashMap();
              var config = LinkedHashMap();
             config["config"] = "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f";
             payload["payload"] = "107";
              element["fmtp"] = [payload,config].toList();
            }

        }
    });
    final sdp_lines = splitter.convert(sdp.toString());
    var newS = sdp_lines.toString();
    String newSDP =  write(sdp_map, null);
    var result = sdp_map.containsValue("level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f");
    print(sdp_map);
    // var matches = sdp.repl(";profile-level-id");
  });
}
