import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static SettingData settings = SettingData();

  static Future<void> loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final data = prefs.getString('settingdata');
    if (data != null) {
      Map<String, dynamic> dataMap = jsonDecode(data);
      settings = SettingData.fromJson(dataMap);
    } else {
      settings = SettingData();
    }
  }

  static void updateSettings({
    int? mapTypeIndex,
    bool? cadastral,
  }) async {
    if (mapTypeIndex != null) settings.mapTypeIndex = mapTypeIndex;
    if (cadastral != null) settings.cadastralOn = cadastral;
    saveSettings();
  }

  // save the data back asyncronously
  static Future<void> saveSettings({SettingData? data}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('settingdata', jsonEncode(data ?? settings));
  }
}

class SettingData {
  int mapTypeIndex;
  bool cadastralOn;

  SettingData({
    this.mapTypeIndex = 4, //MapType.Terrain.index,
    this.cadastralOn = false,
  });

  SettingData.fromJson(Map<String, dynamic> json)
      : mapTypeIndex = json['maptype'] ?? 4, //MapType.Terrain.index,
        cadastralOn = json['cadastral'] ?? false;

  Map<String, dynamic> toJson() => {
        "maptype": mapTypeIndex,
        "cadastral": cadastralOn,
      };
}
