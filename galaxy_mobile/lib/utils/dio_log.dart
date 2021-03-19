import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class LogInterceptors extends Interceptor {
  @override
  Future onRequest(RequestOptions options) async {
    debugPrint("--> ${options.method} ${options.uri}");
    return options;
  }

  // @override
  // FutureOr<dynamic> onRequest(RequestOptions options) {
  //   print(
  //       "--> ${options.method != null ? options.method.toUpperCase() : 'METHOD'} ${"" + (options.baseUrl ?? "") + (options.path ?? "")}");
  //   print("Headers:");
  //   options.headers.forEach((k, v) => print('$k: $v'));
  //   if (options.queryParameters != null) {
  //     print("queryParameters:");
  //     options.queryParameters.forEach((k, v) => print('$k: $v'));
  //   }
  //   if (options.data != null) {
  //     print("Body: ${options.data}");
  //   }
  //   print(
  //       "--> END ${options.method != null ? options.method.toUpperCase() : 'METHOD'}");

  //   return options;
  // }

  // @override
  // FutureOr<dynamic> onError(DioError dioError) {
  //   print(
  //       "<-- ${dioError.message} ${(dioError.response?.request != null ? (dioError.response.request.baseUrl + dioError.response.request.path) : 'URL')}");
  //   print(
  //       "${dioError.response != null ? dioError.response.data : 'Unknown Error'}");
  //   print("<-- End error");
  // }

  // @override
  // FutureOr<dynamic> onResponse(Response response) {
  //   print(
  //       "<-- ${response.statusCode} ${(response.request != null ? (response.request.baseUrl + response.request.path) : 'URL')}");
  //   print("Headers:");
  //   response.headers?.forEach((k, v) => print('$k: $v'));
  //   print("Response: ${response.data}");
  //   print("<-- END HTTP");
  // }
}
