import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disk_space/disk_space.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:janus_client/Plugin.dart';
import 'package:package_info/package_info.dart';

import 'package:provider/provider.dart';
import 'package:system_info/system_info.dart';

class MonitoringData {
  int gatherIntervalInMS;
  int updateIntervalInMS;
  Timer looper;
  Map<String, dynamic> userJson;
  Map<String, dynamic> userJsonExtra;
  SendPort toApp;

  Plugin pluginHandle;
  MediaStreamTrack localAudioTrack;
  MediaStreamTrack localVideoTrack;


  Map<String, dynamic> sentData;
  MonitoringData(SendPort isolateToMainStream) {
    toApp = isolateToMainStream;
  }
  setConnection (
      Plugin pluginHandle,
      MediaStreamTrack localAudioTrack,
      MediaStreamTrack localVideoTrack,
      Map<String, dynamic> user,
      String streamingGateway) {
    // userJsonExtra = userExtra;
    // //userJson = user.toJson();
    // sentData = data;
     this.pluginHandle = pluginHandle;
    this.localAudioTrack = localAudioTrack;
    this.localVideoTrack = localVideoTrack;
    userJson = user;
    userJson["cpu"] = (Platform.isAndroid?"Android ":"iOS ")+Platform.operatingSystemVersion;

    userJson["ram"] = SysInfo.getTotalPhysicalMemory().toString();

    userJson["network"] = "true";
    userJson["streamingGateway"] = streamingGateway;

    userJson["galaxyVersion"] = PackageInfo().version;
  }

  startMonitor() {
    print("monitor start");
    updateLooper();
  }

  stopMonitor() {
    print("monitor stop");
    looper.cancel();
  }

  gatherDataPerInterval() {
    //


  }
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

  monitor_() {
    if (this.pluginHandle  ==null || this.localAudioTrack == null|| this.userJson == null) {
      return; // User not connected.
    }
    RTCPeerConnection pc = (this.pluginHandle.webRTCHandle.pc);
    var defaultTimestamp =   DateTime.now().millisecondsSinceEpoch;
    if (
    pc != null &&
        this.localAudioTrack is MediaStreamTrack &&
        (this.localVideoTrack != null|| this.localVideoTrack is MediaStreamTrack)
    ) {
      const datas = [];
      const SKIP_REPORTS = [
        "certificate",
        "codec",
        "track",
        "local-candidate",
        "remote-candidate"
      ];
      const getStatsPromises = [];
      getStatsPromises.add(
          pc.getStats(this.localAudioTrack).then((stats) {
            var audioReports = {
              "name": "audio",
              "reports": [],
              "timestamp": defaultTimestamp
            };
            stats.forEach((report) {
              // Remove not necessary reports.
              if (!SKIP_REPORTS.contains(report.type)) {
                if (report.timestamp != null) {
                  audioReports["timestamp"] = report.timestamp;
                }
                (audioReports["reports"] as List).add(report);
              }
            });
            datas.add(audioReports);
          })
      );
      if (this.localVideoTrack != null) {
        getStatsPromises.add(
            pc.getStats(this.localVideoTrack).then((stats) {
              var videoReports = {
                "name": "video",
                "reports": [],
                "timestamp": defaultTimestamp
              };
              stats.forEach((report) {
                // Remove not necessary reports.
                if (!SKIP_REPORTS.contains(report.type)) {
                  if (report.timestamp != null) {
                    videoReports["timestamp"] = report.timestamp;
                  }
                  (videoReports["reports"] as List).add(report);
                }
              });
              datas.add(videoReports);
            })
        );
      }

      // Missing some important reports. Add them manually.
      var ids = [this.localAudioTrack.id];
      if (this.localVideoTrack != null) {
        ids.add(this.localVideoTrack.id);
      }
      var mediaSourceIds = [];
      var ssrcs = [];
      getStatsPromises.add(
          pc.getStats(null).then((stats) {
            stats.forEach((report) {
              if (ids.contains(report.values["trackIdentifier"])) {
                if (report.values["mediaSourceId"] != null &&
                    !mediaSourceIds.contains(report.values["mediaSourceId"])) {
                  mediaSourceIds.add(report.values["mediaSourceId"]);
                }
              }
            });
            if (mediaSourceIds.length != null) {
              stats.forEach((report) {
                if (mediaSourceIds.contains(report.values["mediaSourceId"])) {
                  if (report.values["ssrc"] != null &&
                      !ssrcs.contains(report.values["ssrc"])) {
                    ssrcs.add(report.values["ssrc"]);
                  }
                }
              });
            }
            if (ssrcs.length != null) {
              stats.forEach((report) {
                if (
                ssrcs.contains(report.values["ssrc"]) ||
                    mediaSourceIds.contains(report.values["mediaSourceId"]) ||
                    ids.contains(report.values["trackIdentifier"])
                ) {
                  var kind = report.values["kind"];
                  var type = report.type;
                  var data = datas.firstWhere((data) => data.name == kind);
                  if (data && data.reports) {
                    var r = (data["reports"] as List).firstWhere((r) =>
                    r.type == type);
                    if (!r) {
                      (data["reports"] as List).add(report);
                    }
                  }
                }
              });
            }
          })
      );
    }
    // Promise.all(getStatsPromises).then(() => {
    // this.forEachMonitor_(datas, defaultTimestamp);
    // });
    // } else {
    // this.forEachMonitor_([], defaultTimestamp);
    // }
  }

  updateBackend(String data) async {
    print("monitor updateBackend");
    //this.userJson["network"] = (await Connectivity().checkConnectivity()).toString();
  //  userJson["diskFree"] = (await DiskSpace.getFreeDiskSpace).toString();
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
