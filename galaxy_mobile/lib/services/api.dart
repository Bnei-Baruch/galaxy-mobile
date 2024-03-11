import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/config/env.dart';
import 'package:galaxy_mobile/main.dart';
import 'package:galaxy_mobile/models/question.dart';
import 'package:galaxy_mobile/utils/dio_log.dart';
import 'package:galaxy_mobile/models/study_material.dart';

class Room {
  var room;
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
        numUsers = json['numUsers'],
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

// TODO: consider change to RoomGatway
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
  Dio _galaxyBackend;
  Dio _questionsBackend;
  Dio _studyMaterialsBackend;
  Dio _monitor;

  Api() {
    this._galaxyBackend = new Dio();
    this._galaxyBackend.options.baseUrl = APP_API_BACKEND;

    this._questionsBackend = new Dio();
    this._questionsBackend.options.baseUrl = APP_API_QUESTIONS_BACKEND;

    this._studyMaterialsBackend = new Dio();

    this._monitor = new Dio();
    this._monitor.options.baseUrl = APP_MONITORING_BACKEND;

    this._galaxyBackend.interceptors.add(LogInterceptors());
    this._questionsBackend.interceptors.add(LogInterceptors());
    this._studyMaterialsBackend.interceptors.add(LogInterceptors());
  }

  setAccessToken(String accessToken) {
    _galaxyBackend.options.headers["Authorization"] = "Bearer $accessToken";
    _questionsBackend.options.headers["Authorization"] = "Bearer $accessToken";
    _studyMaterialsBackend.options.headers["Authorization"] = "Bearer $accessToken";
  }

  // fetchConfig = () =>
  //         this.logAndParse('fetch config', fetch(this.urlFor('/v2/config'), this.defaultOptions()));
  Future<List<List<RoomData>>> fetchConfig() async {
    final response = await _galaxyBackend.get('/v2/config');

    Map<String, dynamic> gateways = response.data['gateways'];
    Map<String, dynamic> roomsData = gateways['rooms'];
    Map<String, dynamic> streamData = gateways['streaming'];

    List<RoomData> rooms =
        roomsData.values.map((dynamic e) => RoomData.fromJson(e)).toList();
    List<RoomData> streams =
        streamData.values.map((dynamic e) => RoomData.fromJson(e)).toList();

    return [rooms, streams];
  }

  // fetchAvailableRooms = (params = {}) =>
  //     this.logAndParse('fetch available rooms',
  //         fetch(`${this.urlFor('/groups')}?${Api.makeParams(params)}`, this.defaultOptions()));
  Future<List<Room>> fetchAvailableRooms([bool withNumUsers = true]) async {
    final response = await _galaxyBackend
        .get('/groups', queryParameters: {'with_num_users': withNumUsers});
    List<Object> rooms = response.data['rooms'];
    FlutterLogs.logInfo("Api", "fetchAvailableRooms",
        "rooms: " + response.data['rooms'].toString());
    return rooms.map((dynamic e) => Room.fromJson(e)).toList();
  }

  // fetchActiveRooms = () =>
  //       this.logAndParse('fetch active rooms', fetch(this.urlFor('/rooms'), this.defaultOptions()));

  // fetchRoom = (id) =>
  //     this.logAndParse(`fetch room ${id}`, fetch(this.urlFor(`/room/${id}`), this.defaultOptions()));
  Future<Room> fetchRoom(num roomId) async {
    final response = await _galaxyBackend.get('/room/$roomId');
    return Room.fromJson(response.data);
  }

  Future<Response> updateMonitor(String data) async {
    _monitor.options.headers["Content-Type"] = "application/json";
    _monitor.options.headers["Content-Encoding"] = "gzip";
    //zip data

    var stringBytes = utf8.encode(data);
    var gzipBytes = GZipEncoder().encode(stringBytes);
    var compressedString = base64.encode(gzipBytes);

    // var zip = gzip.encode(data.codeUnits);
    // print("zip :" + gzipBytes);
    final response = await _monitor.post(
      "/update",
      data: Stream.fromIterable(
          gzipBytes.map((e) => [e])), //create a Stream<List<int>>
      options: Options(
        headers: {
          Headers.contentLengthHeader: gzipBytes.length, // set content-length
        },
      ),
    );
    FlutterLogs.logInfo("Api", "updateMonitor",
        "sending $data got back ${response.statusMessage}");
    return response;
  }

  Future<Map<String,Object>> getMonitorSpec() async{
    FlutterLogs.logInfo("Api", "getMonitorSpec", "enter");
    final response = await _monitor.get(
      "/spec"
    );
    FlutterLogs.logInfo("Api", "getMonitorSpec", "spec ${response.data} spec status ${response.statusMessage}");
    return response.data;
  }

  Future<Response> updateUser(String id, Map<String, dynamic> user) async {
    _galaxyBackend.options.headers["Content-Type"] = "application/json";

    try {
      print(
          "calling updateUser with params userId = ${id} and url = ${_galaxyBackend.options.baseUrl} access token=${_galaxyBackend.options.headers["Authorization"]} ");
      final response = await _galaxyBackend.put("/users/${id}", data: user);
      return response;
    } catch (error, requestOptions) {
      logger.error(error.toString());
      return Response(statusCode: -1);
    }
  }

  Future<List<Question>> getQuestions(String userId) async {
    // Uncomment for mock data.
    // final response = await Utils.parseJson("get_questions_result.json");
    // await Future.delayed(Duration(seconds: 4));

    final response = await _questionsBackend
        .post('/feed', data: {'serialUserId': userId});
    FlutterLogs.logInfo("Api", "getQuestions", "questions result: ${response.data}");

    List<dynamic> questionsJson = (response.data['feed'] ?? []) as List<dynamic>;
    return questionsJson.map((feed) => Question.fromJson(feed)).toList();
  }

  Future<Response> sendQuestion(String userId, String senderName, String roomName, String content, String gender) async {
    var data = {
      'serialUserId': userId,
      'question': {'content': content},
      'user': {
        'name': senderName,
        'gender': gender,
        'galaxyRoom': roomName
      }
    };
    return _questionsBackend.post('/ask', data: data);
  }

  Future<List<StudyMaterial>> fetchStudyMaterials() async {
    final Response<String> response = await _studyMaterialsBackend.get(APP_STUDY_MATERIALS);
    FlutterLogs.logInfo("Api", "fetchStudyMaterials",  "study material response: $response");

    List<dynamic> studyMaterialsJson = (json.decode(response.data) ?? []) as List<dynamic>;
    return studyMaterialsJson.map((material) => StudyMaterial.fromJson(material)).toList();
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
