import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/config/env.dart';
import 'package:galaxy_mobile/utils/dio_log.dart';

class Room {
  final num room;
  final String janus;
  final String description;
  final bool questions;
  final num numUsers;
// final List<User> users;
  final String region;
// final Object extra" -> null

  Room.fromJson(Map<String, dynamic> json)
      : room = json['room'],
        janus = json['janus'],
        description = json['description'],
        questions = json['questions'],
        numUsers = json['numUse rs'],
        region = json['region'];
}
//
// class Config {
//   final List<Gateway> gateways;
//   Config.fromJson(Map<String, dynamic> json) : gateways = json['gateways'];
// }
//
// class Gateway {
//   final List<RoomsKey> keys;
//   Gateway.fromJson(Map<String, dynamic> json) : keys = json['rooms'];
// }
//
// class RoomsKey{
//   final List<RoomData> rooms ;
//   RoomsKey.fromJson(Map<String, dynamic> json): rooms = json['']
// }
//
// Map jsonObject = json.decode(jsonString);
// Iterable list = json.decode(jsonObject['worksheetData']);
// List<WorksheetData> datasheet = list.map((f) => WorksheetData.fromJson(f)).toList();

class RoomData {
  final String name;
  final String token;
  final String type;
  final String url;
  RoomData.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        token = json['token'],
        type = json['type'],
        url = json['url'];
}

class Api {
  Dio _dio;

  Api() {
    this._dio = new Dio();
    this._dio.options.baseUrl = APP_API_BACKEND;

    this._dio.interceptors.add(LogInterceptors());
  }

  setAccessToken(String accessToken) {
    _dio.options.headers["Authorization"] = "Bearer $accessToken";
  }

  // fetchConfig = () =>
  //         this.logAndParse('fetch config', fetch(this.urlFor('/v2/config'), this.defaultOptions()));
  Future<List<RoomData>> fetchConfig() async {
    final response = await _dio.get('/v2/config');

    Map<String, dynamic> gateways = response.data['gateways'];
    Map<String, dynamic> roomsData = gateways['rooms'];
    print(response.data['rooms']);
    List<RoomData> dd =
        roomsData.values.map((dynamic e) => RoomData.fromJson(e)).toList();
    return dd;
  }

  // fetchAvailableRooms = (params = {}) =>
  //     this.logAndParse('fetch available rooms',
  //         fetch(`${this.urlFor('/groups')}?${Api.makeParams(params)}`, this.defaultOptions()));
  Future<List<Room>> fetchAvailableRooms([bool withNumUsers = true]) async {
    final response = await _dio
        .get('/groups', queryParameters: {'with_num_users': withNumUsers});
    List<Object> rooms = response.data['rooms'];
    print(response.data['rooms']);
    return rooms.map((dynamic e) => Room.fromJson(e)).toList();
  }

  // fetchActiveRooms = () =>
  //       this.logAndParse('fetch active rooms', fetch(this.urlFor('/rooms'), this.defaultOptions()));

  // fetchRoom = (id) =>
  //     this.logAndParse(`fetch room ${id}`, fetch(this.urlFor(`/room/${id}`), this.defaultOptions()));
  Future<Room> fetchRoom(num roomId) async {
    final response = await _dio.get('/room/$roomId');
    return Room.fromJson(response.data);
  }

  //   fetchUsers = () =>
  //       this.logAndParse('fetch users', fetch(this.urlFor('/users'), this.defaultOptions()));

  //   fetchQuad = (col) =>
  //       this.logAndParse(`fetch quad ${col}`, fetch(this.urlFor(`/qids/q${col}`), this.defaultOptions()));

  //   fetchProgram = () =>
  //       this.logAndParse('fetch program', fetch(this.urlFor('/qids'), this.defaultOptions()));

  //   fetchRoomsStatistics = () =>
  //       this.logAndParse('fetch rooms statistics', fetch(this.urlFor('/v2/rooms_statistics'), this.defaultOptions()));

  //   updateQuad = (col, data) => {
  //       const options = this.makeOptions('PUT', data);
  //       return this.logAndParse(`update quad ${col}`, fetch(this.urlFor(`/qids/q${col}`), options));
  //   }

  //   updateUser = (id, data) => {
  //       const options = this.makeOptions('PUT', data);
  //       return this.logAndParse(`update user ${id}`, fetch(this.urlFor(`/users/${id}`), options));
  //   }

  //   updateRoom = (id, data) => {
  //       const options = this.makeOptions('PUT', data);
  //       return this.logAndParse(`update room ${id}`, fetch(this.urlFor(`/rooms/${id}`), options));
  //   }

  //   // Admin API

  //   adminFetchGateways = (params = {}) =>
  //       this.logAndParse('admin fetch gateways',
  //           fetch(`${this.urlFor('/admin/gateways')}?${Api.makeParams(params)}`, this.defaultOptions()));

  //   fetchHandleInfo = (gateway, session_id, handle_id) =>
  //       this.logAndParse('fetch handle_info',
  //           fetch(this.urlFor(`/admin/gateways/${gateway}/sessions/${session_id}/handles/${handle_id}/info`), this.defaultOptions()));

  //   adminFetchRooms = (params = {}) =>
  //       this.logAndParse('admin fetch rooms',
  //           fetch(`${this.urlFor('/admin/rooms')}?${Api.makeParams(params)}`, this.defaultOptions()));

  //   adminCreateRoom = (data) => {
  //       const options = this.makeOptions('POST', data);
  //       return this.logAndParse(`admin create room`, fetch(this.urlFor("/admin/rooms"), options));
  //   }

  //   adminUpdateRoom = (id, data) => {
  //       const options = this.makeOptions('PUT', data);
  //       return this.logAndParse(`admin update room`, fetch(this.urlFor(`/admin/rooms/${id}`), options));
  //   }

  //   adminDeleteRoom = (id) => {
  //       const options = this.makeOptions('DELETE');
  //       return this.logAndParse(`admin delete room`, fetch(this.urlFor(`/admin/rooms/${id}`), options));
  //   }

  //   adminSetConfig = (key, value) => {
  //       const options = this.makeOptions('POST', {value});
  //       return this.logAndParse(`admin set config`, fetch(this.urlFor(`/admin/dynamic_config/${key}`), options));
  //   }

  //   adminResetRoomsStatistics = () => {
  //       const options = this.makeOptions('DELETE');
  //       return this.logAndParse(`admin reset rooms statistics`, fetch(this.urlFor('/admin/rooms_statistics'), options));
  //   }

  //   adminListParticipants = (request, name) => {
  //       let payload = { "janus": "message_plugin", "transaction": randomString(12), "admin_secret": ADMIN_SECRET, plugin: "janus.plugin.videoroom", request};
  //       const options = this.makeOptions('POST', payload);
  //       return this.logAndParse(`admin list participants`, fetch(this.adminUrlFor(name), options));
  //   }

  //   // Auth Helper API

  //   verifyUser = (pendingEmail, action) =>
  //       this.logAndParse(`verify user ${pendingEmail}, ${action}`, fetch(this.authUrlFor(`/verify?email=${pendingEmail}&action=${action}`), this.defaultOptions()));

  //   requestToVerify = (email) =>
  //       this.logAndParse(`request to verify user ${email}`, fetch(this.authUrlFor(`/request?email=${email}`), this.defaultOptions()));

  //   // NOT IN USE
  //   fetchUserInfo = () =>
  //       this.logAndParse(`refresh user info`, fetch(this.authUrlFor('/my_info'), this.defaultOptions()));

}
