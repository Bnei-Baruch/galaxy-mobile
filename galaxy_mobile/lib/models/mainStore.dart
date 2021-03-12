import 'package:flutter/material.dart';
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
  bool audioMode = false;

  void update(AuthService auth, Api api) {
    _auth = auth;
    _api = api;
  }

  void setActiveRoom(int id) {
    activeRoom = availableRooms.firstWhere((element) => element.room == id);
    activeGateway = config.firstWhere((e) => e.name == activeRoom.janus);
    notifyListeners();
  }

  void setAudioMode(bool value) {
    audioMode = value;
    notifyListeners();
  }

  void fetchConfig() async {
    if (config == null) {
      config = await _api.fetchConfig();
    }
    notifyListeners();
  }

  void fetchAvailableRooms([bool withNumUsers = true]) async {
    if (availableRooms == null) {
      availableRooms = await _api.fetchAvailableRooms((withNumUsers));
    }
    notifyListeners();
  }

  void fetchUser() async {
    if (activeUser == null) {
      activeUser = await _auth.getUser();
    }
    notifyListeners();
  }
}
