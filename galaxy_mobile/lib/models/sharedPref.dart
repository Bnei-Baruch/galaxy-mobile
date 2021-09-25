import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static SharedPreferences _sharedPrefs;

  factory SharedPrefs() => SharedPrefs._internal();

  SharedPrefs._internal();

  Future<void> init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }

  Future<void> reset() async {
    return _sharedPrefs.clear();
  }

  String get roomName => _sharedPrefs.getString('roomName') ?? "";
  set roomName(String value) => _sharedPrefs.setString('roomName', value);

  bool get audioMode => _sharedPrefs.getBool('audioMode') ?? false;
  set audioMode(bool value) => _sharedPrefs.setBool('audioMode', value);

  int get audioPreset => _sharedPrefs.getInt('audioPreset') ?? 2;
  set audioPreset(int value) => _sharedPrefs.setInt('audioPreset', value);

  int get videoPreset => _sharedPrefs.getInt('videoPreset') ?? 1;
  set videoPreset(int value) => _sharedPrefs.setInt('videoPreset', value);
}
