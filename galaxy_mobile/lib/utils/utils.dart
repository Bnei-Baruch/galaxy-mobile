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
}
