import 'package:flutter/material.dart';
import 'package:galaxy_mobile/main.dart';
import 'package:galaxy_mobile/models/sharedPref.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/services/keycloak.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:flutter_logs/flutter_logs.dart';

class MainStore extends ChangeNotifier {
  Api _api;
  AuthService _auth;
  MQTTClient _mqttClient;

  List<RoomData> config; // TODO: available gatways
  List<Room> availableRooms;

  User activeUser;
  Room activeRoom;
  RoomData activeGateway;
  bool audioMode;
  int audioPreset;
  int videoPreset;

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
    if (roomName.isEmpty) return;

    activeRoom =
        availableRooms.firstWhere((element) => element.description == roomName);
    activeGateway = config.firstWhere((e) => e.name == activeRoom.janus);

    // TODO: what if the room doesn't exists anymore ?
    SharedPrefs().roomName = roomName;
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
    notifyListeners();
  }

  Future fetchAvailableRooms([bool withNumUsers = true]) async {
    if (availableRooms == null) {
      availableRooms = await _api.fetchAvailableRooms((withNumUsers));
    }
    notifyListeners();
  }

  Future fetchUser() async {
    if (activeUser == null) {
      activeUser = await _auth.getUser();
    }
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

  void updateMonitor(String data) {
    _api.updateMonitor(data);
  }

  void updaterUser(Map<String, dynamic> user) {
    FlutterLogs.logInfo("MainStore", "updaterUser", "");
    _api.updateUser(user["id"], user);
  }
}
