import 'dart:convert';

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
}
