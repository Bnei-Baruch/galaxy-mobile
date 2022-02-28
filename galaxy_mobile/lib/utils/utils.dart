import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Utils {
  static final RegExp _isEnglishOrNonLetterCharRegex = RegExp(r'[\x00-\x7F]');
  static final RegExp _isEnglishCharRegex = RegExp(r'[a-zA-Z]');
  static final RegExp _isRTLCharRegex = RegExp(r'[\u0590-\u07FF\u200F\u202B\u202E\uFB1D-\uFDFD\uFE70-\uFEFC]');

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

  static bool isRTLString(String str) {
    int rtlCharCount = 0;
    int ltrCharCount = 0;
    str.runes.forEach((c) {
      String char = String.fromCharCode(c);
      if (_isRTLCharRegex.hasMatch(char)) {
        rtlCharCount++;
      } else if (_isEnglishCharRegex.hasMatch(char)) {
        ltrCharCount++;
      } else if (!_isEnglishOrNonLetterCharRegex.hasMatch(char)) { // Non RTL & non-English characters.
        ltrCharCount++;
      }
    });
    return rtlCharCount > ltrCharCount;
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

}
