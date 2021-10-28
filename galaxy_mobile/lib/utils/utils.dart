import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class Utils {
  static Future<String> _loadJsonFromAsset(String jsonName) async {
    return await rootBundle.loadString("assets/json/" + jsonName);
  }

  static Future parseJson(String jsonName) async {
    String jsonString = await Utils._loadJsonFromAsset(jsonName);
    final jsonResponse = jsonDecode(jsonString);
    return jsonResponse;
  }

  static List sortAndFilterFeeds(List feeds) {
    feeds = feeds
        .where((feed) =>
            feed["display"]["role"] != ("ghost") &&
            feed["display"]["role"] != ("guest"))
        .toList();
    feeds.sort((a, b) =>
        (a["display"]["timestamp"] as int) -
        (b["display"]["timestamp"] as int));
    return feeds;
  }
  static int getDefaultAudioOnLocal()
  {
    if(Platform.localeName.contains("en")) {
      return 4;
    }
    if(Platform.localeName.contains("ru")) {
      return 3;
    }
    if(Platform.localeName.contains("he")) {
      return 2;
    }
    if(Platform.localeName.contains("es")) {
      return 6;
    }



  }

}
