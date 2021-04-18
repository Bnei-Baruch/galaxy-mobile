import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:galaxy_mobile/config/env.dart';
import 'package:galaxy_mobile/utils/dio_log.dart';
import 'package:jwt_decode/jwt_decode.dart';

final String _clientId = APP_AUTH_CLIENT_ID;
final String _redirectUrl = 'galaxy.mobile://login-callback';
final String _discoveryUrl = APP_AUTH_DISCOVERY_URL;
final List<String> _scopes = <String>[
  "openid",
  "profile",
  "email",
];

// TOOD: replace flutter_auth with https://pub.dev/packages/openid_client

class User {
  final String sub;
  final String name;
  final String title;
  final bool emailVerified;
  final String email;
  final String preferredUsername;
  final String givenName;
  final String familyName;
  final String group;

  User.fromJson(Map<String, dynamic> json)
      : sub = json['sub'],
        name = json['name'],
        title = json['title'],
        emailVerified = json['email_verified'],
        email = json['email'],
        preferredUsername = json['preferred_username'],
        givenName = json['given_name'],
        familyName = json['family_name'],
        group = json['group'];
}

class AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final Dio _dio = Dio();
  String _authEmail;
  String _authToken;

  AuthService() {
    this._dio.interceptors.add(LogInterceptors());
  }

  Future<AuthorizationTokenResponse> signIn() async {
    debugPrint("Sign in");

    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        discoveryUrl: _discoveryUrl,
        scopes: _scopes,
      ),
    );
    this._dio.options.headers["Authorization"] = "Bearer ${result.accessToken}";
    this._authToken = result.accessToken;

    Map<String, dynamic> payload = Jwt.parseJwt(this._authToken);
    print(payload);

    return result;
  }

  Future<User> getUser() async {
    debugPrint("Get User");

    final response = await _dio.get(APP_OPENID_AUTH_USERINFO_ENDPOINT);
    return User.fromJson(response.data);
  }

  String getUserEmail() { return _authEmail; }
  String getAuthToken() { return _authToken; }

  Future<void> logout() async {
    debugPrint("Logout");

    await _dio.get(APP_OPENID_END_SESSION_ENDPOINT);
  }
}


// @immutable
// class MyAppUser {
//   const MyAppUser({
//     @required this.uid,
//     this.email,
//     this.photoUrl,
//     this.displayName,
//   });

//   final String uid;
//   final String email;
//   final String photoUrl;
//   final String displayName;
// }

// abstract class AuthService {
//   Future<MyAppUser> currentUser();
//   Future<MyAppUser> signInAnonymously();
//   Future<MyAppUser> signInWithEmailAndPassword(String email, String password);
//   Future<MyAppUser> createUserWithEmailAndPassword(
//       String email, String password);
//   Future<void> sendPasswordResetEmail(String email);
//   Future<MyAppUser> signInWithEmailAndLink({String email, String link});
//   bool isSignInWithEmailLink(String link);
//   Future<void> sendSignInWithEmailLink({
//     @required String email,
//     @required String url,
//     @required bool handleCodeInApp,
//     @required String iOSBundleId,
//     @required String androidPackageName,
//     @required bool androidInstallApp,
//     @required String androidMinimumVersion,
//   });
//   Future<MyAppUser> signInWithGoogle();
//   Future<MyAppUser> signInWithFacebook();
//   // Future<MyAppUser> signInWithApple({List<Scope> scopes});
//   Future<void> signOut();
//   Stream<MyAppUser> get onAuthStateChanged;
//   void dispose();
// }
