import 'dart:isolate';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/src/interface/media_stream.dart';
import 'package:galaxy_mobile/chat/chatMessage.dart';
import 'package:galaxy_mobile/models/sharedPref.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/services/keycloak.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:janus_client/Plugin.dart';

// TODO: change to prefernces store.
class MainStore extends ChangeNotifier {
  Api _api;
  AuthService _auth;
  MQTTClient _mqttClient;

  List<List<RoomData>> config; // TODO: available gatways
  List<Room> availableRooms;
  List<ChatMessage> chatMessageList = [];

  User activeUser;
  Room activeRoom;
  RoomData activeGateway;
  RoomData activeStreamGateway;
  bool audioMode; // TODO: doesn't belong here
  int audioPreset;
  int videoPreset;

  Function() chatUpdater;

  Plugin plugin;

  MediaStream localStream;

  SendPort monitorPort;




  Future init() async {
    await Future.wait([fetchUser(), fetchConfig(), fetchAvailableRooms(false)]);

    setActiveRoom(SharedPrefs().roomName);
    setAudioMode(SharedPrefs().audioMode);
    setAudioPreset(SharedPrefs().audioPreset);
    setVideoPreset(SharedPrefs().videoPreset);

    _mqttClient = MQTTClient();
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

  void setAudioMode(bool value) {
    SharedPrefs().audioMode = value;
    audioMode = value;
    notifyListeners();
  }

  Future fetchConfig() async {
    if (config == null) {
      config = await _api.fetchConfig();
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

  // TODO: this function should be declared as async.
  void updateMonitor(String data) {
    _api.updateMonitor(data);
  }

  // TODO: this function should be declared as async.
  Future<Response> updaterUser(Map<String, dynamic> user) {
    FlutterLogs.logInfo("MainStore", "updaterUser", "");
    return _api.updateUser(user["id"], user);
  }

  // CR: doesn't belong here, should be in the chat widget state,
  // this is never cleared, will eventually bloat memory.
  List<ChatMessage> getChatMessages() {
    return chatMessageList;
  }

  void addChatMessage(ChatMessage msg) {
    chatMessageList.add(msg);
    if (chatUpdater != null) {
      chatUpdater();
    }
  }

  void setChatUpdater(Function() callback) {
    chatUpdater = callback;
  }

  void setVideoRoomParams(Plugin pluginHandle, MediaStream myStream) {
    plugin = pluginHandle;
    localStream = myStream;
  }

   getStats() async {
    var audio = await plugin.webRTCHandle.pc.getStats(localStream.getAudioTracks().first);
    var video = await plugin.webRTCHandle.pc.getStats(localStream.getVideoTracks().first);
    monitorPort.send({"report" :{"audio":audio,"video":video}});
  }

  void setMonitorPort(SendPort mainToIsolateStream) {
    monitorPort = mainToIsolateStream;
  }
}
