import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/sharedPref.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';

class MainStore extends ChangeNotifier {
  Api _api;
  AuthService _auth;

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
  }

  void update(AuthService auth, Api api) {
    _auth = auth;
    _api = api;
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
}
