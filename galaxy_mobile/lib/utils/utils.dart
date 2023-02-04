import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Utils {
  static Future<String> _loadJsonFromAsset(String jsonName) async {
    return await rootBundle.loadString("assets/json/" + jsonName);
  }

  static Future parseJson(String jsonName) async {
    String jsonString = await Utils._loadJsonFromAsset(jsonName);
    final jsonResponse = jsonDecode(jsonString);
    return jsonResponse;
  }
  static Future parseTxt(String jsonName) async {
    String txtString = await Utils._loadJsonFromAsset(jsonName);

    return txtString;
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

  static int getDefaultAudioOnLocal() {
    if (Platform.localeName.contains("en")) {
      return 4;
    }
    if (Platform.localeName.contains("ru")) {
      return 3;
    }
    if (Platform.localeName.contains("he")) {
      return 2;
    }
    if (Platform.localeName.contains("es")) {
      return 6;
    }
    // TODO: what is the default value?
  }

  /// Formats a date string for the [timestamp] in the provided [format].
  ///
  /// [timestamp] must be in milliseconds and [format] must be suitable for
  /// use in [DateFormat].
  static String formatTimestampAsDate(int timestamp, String format) {
    DateTime dateTime = new DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateFormat dateFormat = new DateFormat(format);
    return dateFormat.format(dateTime);
  }

  static bool isRTL(String text) {
    return Bidi.detectRtlDirectionality(text);
  }
}
