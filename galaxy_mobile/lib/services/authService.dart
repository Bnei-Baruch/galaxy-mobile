import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_http_cache/dio_http_cache.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/config/env.dart';
import 'package:galaxy_mobile/models/sharedPref.dart';
import 'package:galaxy_mobile/utils/dio_log.dart';
import 'package:jwt_decode/jwt_decode.dart';


// TOOD: replace flutter_auth with https://pub.dev/packages/openid_client

class User {
  final String id;
  final String sub;
  final String name;
  final String title;
  final bool emailVerified;
  final String email;
  final String preferredUsername;
  final String givenName;
  final String familyName;
  final String group;
  final int rfid;

  User.fromJson(Map<String, dynamic> json)
      : sub = json['sub'],
        id = json['sub'],
        rfid = json['rfid'],
        name = json['name'],
        title = json['title'],
        emailVerified = json['email_verified'],
        email = json['email'],
        preferredUsername = json['preferred_username'],
        givenName = json['given_name'],
        familyName = json['family_name'],
        group = json['group'];

  Map<String, dynamic> toJson() => {
        'sub': sub,
        'id': sub,
        'name': name,
        'title': title,
        'emailVerified': emailVerified,
        'email': email,
        'preferredUsername': preferredUsername,
        'givenName': givenName,
        'familyName': familyName,
        'rfid': rfid,
        'group': group,
      };

  @override
  String toString() {
    return '{sub: ${this.sub}, '
        'name: ${this.name} ,'
        'title: ${this.title} ,'
        'emailVerified: ${this.emailVerified} ,'
        'email: ${this.email} ,'
        'preferredUsername: ${this.preferredUsername} ,'
        'givenName: ${this.givenName} ,'
        'familyName: ${this.familyName} ,'
        'group: ${this.group}}';
  }
}

class AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final Dio _dio = Dio();
  DioCacheManager _dioCacheManager = DioCacheManager(CacheConfig());


  AuthorizationTokenResponse authResponse;
  String _authEmail;
  String _authToken;

  AuthService() {
    _dio.interceptors.add(_dioCacheManager.interceptor);
    this._dio.interceptors.add(LogInterceptors());
  }

  Future<AuthorizationTokenResponse> signIn() async {
    FlutterLogs.logInfo("AuthService", "signIn", "Signed in");

    this.authResponse = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        APP_AUTH_CLIENT_ID,
        APP_AUTH_REDIRECT_URL,
        promptValues:
            (_authToken == null && checkSessionExpired()) ? ['login'] : [],
        discoveryUrl: APP_AUTH_DISCOVERY_URL,
        scopes: ["openid", "profile","email"],
      ),
    );
    this._dio.options.headers["Authorization"] = "Bearer ${this.authResponse.accessToken}";
    this._authToken = this.authResponse.accessToken;

    // TODO: why can't you take the preferred_username from getUser ?
    Map<String, dynamic> payload = Jwt.parseJwt(this.authResponse.accessToken);
    FlutterLogs.logInfo("AuthService", "signIn", "parsed token: $payload");
    _authEmail = payload['preferred_username'];

    return this.authResponse;
  }

  Future<User> getUser() async {
    FlutterLogs.logInfo("AuthService", "signIn", "getting user");
    final response = await _dio.get(APP_OPENID_AUTH_USERINFO_ENDPOINT);
    return User.fromJson(response.data);
  }

  String getUserEmail() {
    return _authEmail;
  }

  String getAuthToken() {
    return _authToken;
  }

  Future<void> logout() async {
    FlutterLogs.logInfo("AuthService", "signIn", "logout");
    _authToken = null;
    await _dio.get("$APP_OPENID_END_SESSION_ENDPOINT?id_token_hint=${authResponse.idToken}");
  }

  bool checkSessionExpired() {
    var date = SharedPrefs().sessionDate;
    if (date == 0) {
      var now = DateTime.now().millisecondsSinceEpoch;
      SharedPrefs().sessionDate = now;
      return true;
    } else {
      var now = DateTime.now();
      var session = DateTime.fromMillisecondsSinceEpoch(date);
      if (session.difference(now).inDays > 30) {
        return true;
      } else {
        return false;
      }
    }
  }
}
