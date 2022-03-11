import 'dart:isolate';
import 'dart:math';

import 'package:connectivity_plus_platform_interface/src/enums.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/src/interface/media_stream.dart';
import 'package:galaxy_mobile/models/shared_pref.dart';
import 'package:galaxy_mobile/screens/dashboard/dashboard.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/auth_service.dart';
import 'package:galaxy_mobile/services/keycloak.dart';
import 'package:galaxy_mobile/services/mqtt_client.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:janus_client/Plugin.dart';

// TODO: Find a place for this.
class RoomUser {
  String id;
  String name;
  bool camOn;
  bool micOn;
  bool isCurrentUser;
  int timeJoined;

  RoomUser({ this.id, this.name, this.camOn, this.micOn, this.isCurrentUser, this.timeJoined });
}

// TODO: change to prefernces store.
class MainStore extends ChangeNotifier {
  Api _api;
  AuthService _auth;
  MQTTClient _mqttClient;

  List<List<RoomData>> config; // TODO: available gatways
  List<Room> availableRooms;
  Map<String,Object> spec;
  User activeUser;
  Room activeRoom;
  RoomData activeGateway;
  RoomData activeStreamGateway;
  List<RoomUser> friendsInRoom = [];
  bool audioMode; // TODO: doesn't belong here
  int audioPreset;
  int videoPreset;
  String signal;

  Plugin plugin;

  MediaStream localStream;
  SendPort monitorPort;
  int audioDevice;
  String version;

  ConnectivityResult network;

  Future init() async {
    await Future.wait([fetchUser(), fetchConfig(), fetchAvailableRooms(false)]);

    setActiveRoom(SharedPrefs().roomName);
    setAudioMode(SharedPrefs().audioMode);
    setAudioPreset(SharedPrefs().audioPreset);
    setVideoPreset(SharedPrefs().videoPreset);
    setAudioDevice(SharedPrefs().audioDevice);

    _mqttClient.init(_auth.getUserEmail(),  _auth.getToken().accessToken, activeUser.id);
  }

  void update(AuthService auth, Api api, MQTTClient mqttClient) {
    _auth = auth;
    _api = api;
    _mqttClient = mqttClient;
  }

  void setActiveRoom(String roomName) {
    if (roomName == null) {
      activeRoom = null;
      activeGateway = null;
      SharedPrefs().roomName = null;
    } else if (roomName.isNotEmpty) {
      activeRoom = availableRooms
          .firstWhere((element) => element.description == roomName);
      activeGateway = config[0].firstWhere((e) => e.name == activeRoom.janus);

      activeStreamGateway =
          config[1][(Random().nextDouble() * config[1].length).floor()];
      // TODO: what if the room doesn't exists anymore ?
      SharedPrefs().roomName = roomName;

      notifyListeners();
    }
  }

  void setFriendsInRoom(List<RoomUser> friends) {
    friendsInRoom = friends;
    notifyListeners();
  }

  void setAudioMode(bool value) {
    SharedPrefs().audioMode = value;
    audioMode = value;
    notifyListeners();
  }

  Future fetchConfig() async {
    if (config == null) {
      config = await _api.fetchConfig();
    }
    if( spec == null) {
      spec = await _api.getMonitorSpec();
    }
    notifyListeners();
  }

  Future fetchAvailableRooms([bool withNumUsers = true]) async {
    if (availableRooms == null) {
      availableRooms = await _api.fetchAvailableRooms((withNumUsers));
    }
    notifyListeners();
  }

  Future fetchUser() async {
    activeUser = await _auth.getUser();
    notifyListeners();
  }

  void setAudioPreset(int audioPreset) {
    SharedPrefs().audioPreset = audioPreset;
    this.audioPreset = audioPreset;
    notifyListeners();
  }

  void setVideoPreset(int videoPreset) {
    SharedPrefs().videoPreset = videoPreset;
    this.videoPreset = videoPreset;
    notifyListeners();
  }

  void setAudioDevice(int audioDevice) {
    SharedPrefs().audioDevice = audioDevice;
    this.audioDevice = audioDevice;
    notifyListeners();
  }

  // TODO: this function should be declared as async.
  void updateMonitor(String data) {
    _api.updateMonitor(data);
  }

  // TODO: this function should be declared as async.
  Future<Response> updaterUser(Map<String, dynamic> user) {
    FlutterLogs.logInfo("MainStore", "updaterUser", "");
    return _api.updateUser(user["id"], user);
  }

  void setVideoRoomParams(Plugin pluginHandle, MediaStream myStream) {
    plugin = pluginHandle;
    localStream = myStream;
  }

  getStats() async {
    var audio = await plugin.webRTCHandle.pc.getStats(localStream.getAudioTracks().first);
    var video = await plugin.webRTCHandle.pc.getStats(localStream.getVideoTracks().first);
    var general = await plugin.webRTCHandle.pc.getStats(null);
    // monitorPort.send({"type":"report","value" :{"audio":audio,"video":video,"general":general,"videoTrackId":localStream.getVideoTracks().first.id,"audioTrackId":localStream.getAudioTracks().first.id}});
    monitorPort.send({
      "type": "report",
      "value":{
        "audio": null,
        "video": null,
        "general": null,
        "videoTrackId": localStream.getVideoTracks().first.id,
        "audioTrackId": localStream.getAudioTracks().first.id
      }
    });
  }

  void setMonitorPort(SendPort mainToIsolateStream) {
    monitorPort = mainToIsolateStream;
  }

  void setSignal(data) {
    FlutterLogs.logInfo("MainStore", "setSignal", data);
    signal = data;
    notifyListeners();
  }

  DateTime getLastLogin() {
    FlutterLogs.logInfo("MainStore", "last login date", SharedPrefs().lastLogin.toString());
    return SharedPrefs().lastLogin;
  }

  void setLastLogin(DateTime dateTime) {
    FlutterLogs.logInfo("MainStore", "set last login date", dateTime.toString());
    SharedPrefs().lastLogin = dateTime;
  }
}
