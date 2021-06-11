import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_http_cache/dio_http_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/config/env.dart';
import 'package:galaxy_mobile/utils/dio_log.dart';
import 'package:jwt_decode/jwt_decode.dart';

import 'keycloak.dart';

class AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final Dio _dio = Dio();
  DioCacheManager _dioCacheManager = DioCacheManager(CacheConfig());

  TokenResponse tokenResponse;

  AuthService() {
    // TODO: why do you need DioCacheManager?
    _dio.interceptors.add(_dioCacheManager.interceptor);
    this._dio.interceptors.add(LogInterceptors());
  }

  Future<TokenResponse> signIn() async {
    FlutterLogs.logInfo("AuthService", "signIn", "Signed in");

    this.tokenResponse = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        APP_AUTH_CLIENT_ID,
        APP_AUTH_REDIRECT_URL,
        discoveryUrl: APP_AUTH_DISCOVERY_URL,
        scopes: ["openid", "profile", "email", "roles"],
      ),
    );
    this._dio.options.headers["Authorization"] =
        "Bearer ${this.tokenResponse.accessToken}";

    return this.tokenResponse;
  }

  Future<User> getUser() async {
    FlutterLogs.logInfo("AuthService", "signIn", "getting user");
    final response = await _dio.get(APP_OPENID_AUTH_USERINFO_ENDPOINT);
    var roles = getUserRoles();
    response.data["roles"] = roles;
    response.data["question"] = false;
    response.data["camera"] = false;
    response.data["timestamp"] = DateTime.now().millisecondsSinceEpoch;
    return User.fromJson(response.data);
  }

  String getUserEmail() {
    // TODO: why can't you take the preferred_username from getUser ?
    Map<String, dynamic> payload = Jwt.parseJwt(this.tokenResponse.accessToken);
    FlutterLogs.logInfo(
        "AuthService", "get user email", "parsed token: $payload");
    return payload['preferred_username'];
  }

  List<String> getUserRoles() {
    Map<String, dynamic> payload = Jwt.parseJwt(this.tokenResponse.accessToken);
    FlutterLogs.logInfo("AuthService", "get roles", "parsed token: $payload");
    Map<String, dynamic> realm = payload['realm_access'];
    List<String> val = List.from(realm['roles']);
    return val;
  }

  TokenResponse getToken() {
    return this.tokenResponse;
  }

  Future<void> logout() async {
    FlutterLogs.logInfo("AuthService", "signIn", "logout");
    await _dio.get(
        "$APP_OPENID_END_SESSION_ENDPOINT?id_token_hint=${tokenResponse.idToken}");
  }

  Future<void> refreshToken() async {
    this.tokenResponse = await this._appAuth.token(TokenRequest(
          APP_AUTH_CLIENT_ID,
          APP_AUTH_REDIRECT_URL,
          refreshToken: this.tokenResponse.refreshToken,
          grantType: GrantType.refreshToken,
          discoveryUrl: APP_AUTH_DISCOVERY_URL,
        ));
  }
}
