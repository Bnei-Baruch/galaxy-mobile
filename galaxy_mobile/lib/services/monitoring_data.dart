import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:package_info/package_info.dart';

import 'package:galaxy_mobile/services/keycloak.dart';
import 'package:provider/provider.dart';

class MonitoringData {
  int gatherIntervalInMS;
  int updateIntervalInMS;
  Timer looper;
  Map<String, dynamic> userJson;
  Map<String, dynamic> userJsonExtra;
  SendPort toApp;

  Map<String, dynamic> sentData;
  MonitoringData(SendPort isolateToMainStream) {
    toApp = isolateToMainStream;
  }
  setConnection(
      String pluginHandle,
      MediaStreamTrack localAudioTrack,
      MediaStreamTrack localVideoTrack,
      Map<String, dynamic> user,
      String streamingGateway) {
    // userJsonExtra = userExtra;
    // //userJson = user.toJson();
    // sentData = data;
    userJson = user;
    userJson["cpu"] = "Android";
    userJson["ram"] = "4GB";
    userJson["network"] = "true";
    userJson["streamingGateway"] = "glx4";

    userJson["galaxyVersion"] = "1.0.9";
  }

  startMonitor() {
    print("monitor start");
    updateLooper();
  }

  stopMonitor() {
    print("monitor stop");
    looper.cancel();
  }

  gatherDataPerInterval() {}
  updateLooper() {
    print("monitor updateLooper");
    int counter = 1;
    //loop for 1 min - in this 1 min gather data oer sec [call gatherDataPerInterval], after one min send data to backend
    looper = Timer.periodic(Duration(seconds: 1), (timer) {
      gatherDataPerInterval();
      if (counter == 60) {
        updateBackend("ff");
        counter = 1;
      } else {
        counter += 1;
      }
    });
  }

  updateBackend(String data) async {
    print("monitor updateBackend");
    var data = {
      "user": this.userJson,
      "data": [],
    };
    // var user_monitor = await Utils.parseJson("user_monitor_example.json");
    // var data_monitor = await Utils.parseJson("monitor_data.json");
    // Map<String, dynamic> data_exp = {
    //   "user": user_monitor,
    //   "data": data_monitor
    // };

    String data_to_send = json.encode(data);
    toApp.send(data_to_send);

    //Api().updateMonitor(data.toString());
  }
}
