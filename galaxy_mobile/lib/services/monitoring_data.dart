import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

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


final ONE_SECOND_IN_MS = 1000;
final ONE_MINUTE_IN_MS = 60 * 1000;
final FIVE_SECONDS_IN_MS = 5 * ONE_SECOND_IN_MS;

final FIRST_BUCKET = 5 * ONE_SECOND_IN_MS;
final MEDIUM_BUCKET = 15 * ONE_SECOND_IN_MS;
final FULL_BUCKET = 45 * ONE_SECOND_IN_MS;

final INITIAL_STORE_INTERVAL = 5 * ONE_MINUTE_IN_MS;
final INITIAL_SAMPLE_INTERVAL = FIVE_SECONDS_IN_MS;
final MAX_EXPONENTIAL_BACKOFF_MS = 10 * ONE_MINUTE_IN_MS;

class MonitoringData {



  var fetchErrors = 0;
  var lastFetchTimestamp = 0;
  var lastUpdateTimestamp = 0;

  final LINK_STATE_INIT = "init";
  final LINK_STATE_GOOD = "good";
  final LINK_STATE_MEDIUM = "medium";
  final LINK_STATE_WEAK = "weak";

  int gatherIntervalInMS;
  int updateIntervalInMS;
  Timer looper;
  Map<String, dynamic> userJson;
  Map<String, dynamic> userJsonExtra;
  SendPort toApp;

  Plugin pluginHandle;
  MediaStreamTrack localAudioTrack;
  MediaStreamTrack localVideoTrack;
  var miscData = {};
  var storedData = [];
  var scoreData = [];
  var spec = {
  "sample_interval": INITIAL_SAMPLE_INTERVAL,
  "store_interval": INITIAL_STORE_INTERVAL,
  "metrics_whitelist": [],
  };


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

  navigatorConnectionData(var timestamp) {
    //const c = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    // if (!c) {
      return null;
    // }
    // return {
    //   timestamp,
    //   downlink: c.downlink,
    //   downlinkMax: c.downlinkMax,
    //   effectiveType: c.effectiveType,
    //   rtt: c.rtt,
    //   saveData: c.saveData,
    //   type: c.type,
    // };
  }

  onSlowLink(slowLinkType, lost) {
    var countName = "slow-link-${slowLinkType}";
    var lostName = "slow-link-${slowLinkType}-lost";
    if (( ! this.miscData.containsKey(countName)) ) {
    this.miscData[countName] = 0;
    }
    this.miscData[countName]++;
    if (!( miscData.containsKey(lostName))) {
    this.miscData[lostName] = 0;
    }
    this.miscData[lostName] += lost;
    }


  Map getMiscData(var timestamp) {

    return Map.of({timestamp:this.miscData, "type": "misc"});
  }
  forEachMonitor(List datas, defaultTimestamp) {
    var dataTimestamp = (datas != null && datas.length >0 && datas[0].timestamp) || defaultTimestamp;
    var navigatorConnection = this.navigatorConnectionData(dataTimestamp);
    if (navigatorConnection) {
      datas.add({"name": "NetworkInformation", "reports": [navigatorConnection], "timestamp": dataTimestamp});
    }
    var misc = this.getMiscData(dataTimestamp);
    if (misc != null) {
      datas.add({"name": "Misc", "reports": [misc], "timestamp": dataTimestamp});
    }
    if (datas.length >0) {
      this.storedData.add(datas);
    }

    // This is Async callback. Sort stored data.
    this.storedData.sort((a, b) => a[0].timestamp - b[0].timestamp);
    // Throw old stats, STORE_INTERVAL from last timestamp stored.
    var lastTimestamp = this.lastTimestamp();
    if (lastTimestamp) {
      this.storedData.removeWhere((data) => data[0].timestamp >= lastTimestamp - this.spec["store_interval"]);
    }
    if (datas.length > 0 /*&& this.onDataCallback*/ && this.storedData.length>0) {
      //this.onDataCallback(this.storedData[this.storedData.length - 1]);
    }
    this.updateScore();

    var  backoff = min(MAX_EXPONENTIAL_BACKOFF_MS, FIVE_SECONDS_IN_MS * pow(2, this.fetchErrors));
    if (
    (lastUpdateTimestamp >0 && fetchErrors>0) /* Fetch for the first time */ ||
        (lastTimestamp - this.lastUpdateTimestamp > this.spec["store_interval"] /* Fetch after STORE_INTERVAL */ &&
            lastTimestamp - this.lastFetchTimestamp > backoff) /* Fetch after errors backoff */
    ) {
      this.updateBackend(/*logToConsole=*/"");
    }
  }

  getMetricValue(data, metric, prefix) {
    if (data is List) {
      var e = data.find((e) =>
          metric.startsWith([prefix, e.name ? "[name:${e.name}]" : "[type:${e.type}]"].filter((part) => part).join("."))
      );
      if (e  == null) {
        return null;
      }
      return this.getMetricValue(
          e,
          metric,
          [prefix, e.name ? "[name:${e.name}]" : "[type:${e.type}]"].filter((part) => part).join(".")
      );
    } else if (data != null &&  data is Map) {
      data.forEach((key, value)  {
        if (metric.startsWith("${prefix}.${key}")) {
          var ret = getMetricValue(value, metric, "${prefix}.${key}");
          if (ret != null) {
            return ret;
          }
        }
      });
      // Did not find metric.
      return null;
    }
    if (metric != prefix) {
      // console.log(`Expected leaf ${data} to fully match prefix ${prefix} to ${metric}`);
      return null;
    }
    return data;
  }

  filterData(data, metrics, prefix) {
    if (data is List) {
       data
          .removeWhere((e) =>
          metrics.any((m) =>
              m.startsWith([prefix, e.name ? "[name:${e.name}]" : "[type:${e.type}]"].join("."))
          )
      );
      data
          .map((e) =>
          this.filterData(
              e,
              metrics,
              [prefix, e.name ? "[name:${e.name}]" : "[type:${e.type}]"].join(".")
          )
      );
      return data;
    } else if (data is Map ) {
      // const filterField = ["type", "name"].find((f) => prefix.split(".").slice(-1)[0].startsWith(`[${f}`));
      const copy = {};
      // Object.entries(data)
      //     .filter(([key, value]) =>
      //     metrics.some((m) => m.startsWith(`${prefix}.${key}`) || [filterField, "timestamp"].includes(key))
      // )
      //     .forEach(
      //         ([key, value]) =>
      //     (copy[key] = [filterField, "timestamp"].includes(key)
      //         ? value
      //         : this.filterData(value, metrics, `${prefix}.${key}`))
      // );
      return copy;
    }
    if (!metrics.some((m) => m == prefix)) {
     // console.log(`Expected leaf ${data} to fully match prefix ${prefix} to one of the metrics ${metrics}`);
    }
    return data;
  }

  updateScore() {
    var  data = this.storedData.map((d) => this.filterData(d, this.spec["metrics_whitelist"], ""));
    data.forEach((d) {
    if (d.length && d[0]["timestamp"]) {
        var  timestamp = d[0]["timestamp"];
        var lastScoreTimestamp = scoreData.length >0?? scoreData[scoreData.length - 1][0]["timestamp"];
        if (timestamp && (lastScoreTimestamp >0|| lastScoreTimestamp < timestamp)) {
    this.scoreData.add(d);
    }
    }
    });
    // Remove older then 10 minutes.
    var last = scoreData[scoreData.length - 1];
    if (last && last.length && /* [0] - audio */ last[0].timestamp) {
    var lastTimestamp = last[0]["timestamp"];
    scoreData.removeWhere((d)  {
    var timestamp = d[0]["timestamp"];
    return timestamp>0?? timestamp >= lastTimestamp - FULL_BUCKET;
    });
    var input = {
    // Last timestamp.
    "timestamp": [lastTimestamp],
    // Last timestamp values.
    "data": (spec["metrics_whitelist"] as List).map((metric) => [getMetricValue(last, metric, "")]),
    // Mapping form metric to it's index.
    "index": (spec["metrics_whitelist"] as List).reduce((idx, acc) {
    // reduce((acc, metric, idx) => {
    acc["metric"] = idx;
    return acc;
    },
    "stats": (spec["metrics_whitelist"] as List).map((metric)  {
    var stats = [new Stats(), new Stats(), new Stats()];
    stats.forEach((stat, statIndex) =>
    this.scoreData
        .map((d) {
    return [d[0].timestamp, this.getMetricValue(d, metric, "")];
    })
        .forEach(([timestamp, v])  {
    switch (statIndex) {
    case 0: // Smallest time bucket.
    if (lastTimestamp - timestamp > FIRST_BUCKET) {
    return; // Skipp add.
    }
    break;
    case 1: // Medium time bucket.
    if (lastTimestamp - timestamp > MEDIUM_BUCKET) {
    return; // Skipp add.
    }
    break;
    case 2: // Full time bucket
    if (lastTimestamp - timestamp > FULL_BUCKET) {
    return; // Skipp add.
    }
    break;
    default:
    break;
    }
    stat.add(v, timestamp);
    })
    );
    return stats;
    })),
    };
    var values = dataValues(input, lastTimestamp);
    // Keep commented out logs for debugging.
    // console.log(input, values);
    // console.log('last', this.scoreData.length, input.data.map(arr => arr[0] === undefined ? 'undefined' : arr[0]).join(' | '));
    // console.log('score', values.score.value, values.score.formula);
    // console.log('audio score 1min', values.audio.jitter.oneMin && values.audio.jitter.oneMin.mean.value, values.audio.packetsLost.oneMin && values.audio.packetsLost.oneMin.mean.value, values.audio.roundTripTime.oneMin && values.audio.roundTripTime.oneMin.mean.value);
    // console.log('audio score 3min', values.audio.jitter.threeMin && values.audio.jitter.threeMin.mean.value, values.audio.packetsLost.threeMin && values.audio.packetsLost.threeMin.mean.value, values.audio.roundTripTime.threeMin && values.audio.roundTripTime.threeMin.mean.value);
    // console.log('video score 1min', values.video.jitter.oneMin && values.video.jitter.oneMin.mean.value, values.video.packetsLost.oneMin && values.video.packetsLost.oneMin.mean.value, values.video.roundTripTime.oneMin && values.video.roundTripTime.oneMin.mean.value);
    // console.log('video score 3min', values.video.jitter.threeMin && values.video.jitter.threeMin.mean.value, values.video.packetsLost.threeMin && values.video.packetsLost.threeMin.mean.value, values.video.roundTripTime.threeMin && values.video.roundTripTime.threeMin.mean.value);
    if (onStatus) {
    const firstTimestamp = scoreData[0][0].timestamp;
    const formula = `Score ${values.score.view} = ${values.score.formula}`;
    // console.log('Connection', formula, values.score.value);
    if (lastTimestamp - firstTimestamp >= MEDIUM_BUCKET) {
    if (values.score.value < 10) {
    this.onStatus(LINK_STATE_GOOD, formula);
    } else if (values.score.value < 100) {
    this.onStatus(LINK_STATE_MEDIUM, formula);
    } else {
    this.onStatus(LINK_STATE_WEAK, formula);
    }
    } else {
    this.onStatus(LINK_STATE_INIT, formula);
    }
    }
    }
  }


  lastTimestamp() {
    return this.storedData.length>0 &&
        this.storedData[this.storedData.length - 1] &&
        this.storedData[this.storedData.length - 1].length
        ? this.storedData[this.storedData.length - 1][0].timestamp
        : 0;
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

Stats = class {
constructor() {
this.mean = 0;
this.dSquared = 0;
this.length = 0;
this.maxAddedTimestamp = 0;
this.maxRemovedTimestamp = 0;
this.numAdds = 0;
this.numRemoves = 0;
this.numEmptyRemoves = 0;
}

add(value, timestamp) {
if (isNaN(value) || !isFinite(value)) {
// May be string value. Ignore.
return;
}

this.numAdds++;
if (timestamp > this.maxAddedTimestamp) {
this.maxAddedTimestamp = timestamp;
} else {
console.error(
`Expecting to add only new values, old timestamp: ${timestamp} found, max ${this.maxAddedTimestamp}.`
);
}
this.length++;

const meanIncrement = (value - this.mean) / this.length;
const newMean = this.mean + meanIncrement;

const dSquaredIncrement = (value - newMean) * (value - this.mean);
let newDSquared = (this.dSquared * (this.length - 1) + dSquaredIncrement) / this.length;
if (isNaN(newDSquared)) {
console.log("add newDSquared", newDSquared, this.dSquared, this.length, dSquaredIncrement);
}
if (newDSquared < 0) {
// Correcting float inaccuracy.
if (newDSquared < -0.00001) {
console.warn(`Add: newDSquared negative: ${newDSquared}. Setting to 0. ${value}, ${timestamp} ${this}`);
}
newDSquared = 0;
}

this.mean = newMean;
this.dSquared = newDSquared;
}

remove(value, timestamp) {
if (isNaN(value) || !isFinite(value)) {
// May be string value. Ingore.
return;
}
if (timestamp > this.maxRemovedTimestamp) {
this.maxRemovedTimestamp = timestamp;
} else {
console.warn(
`Expecting to remove only new values, old timestamp: ${timestamp} found, max ${this.maxRemovedTimestamp}.`
);
}
if (this.length <= 1) {
if (this.length === 1) {
this.numRemoves++;
} else {
this.numEmptyRemoves++;
}
console.warn(`Empty stats (${value}, ${timestamp}, ${this}).`);
this.mean = 0;
this.dSquared = 0;
this.length = 0;
return;
}
this.numRemoves++;
this.length--;

const meanIncrement = (this.mean - value) / this.length;
const newMean = this.mean + meanIncrement;

const dSquaredIncrement = (newMean - value) * (value - this.mean);
let newDSquared = (this.dSquared * (this.length + 1) + dSquaredIncrement) / this.length;
if (isNaN(newDSquared)) {
console.log("remove newDSquared", newDSquared, this.dSquared, this.length, dSquaredIncrement);
}
if (newDSquared < 0) {
// Correcting float inaccuracy.
if (newDSquared < -0.00001) {
console.warn(`Remove: newDSquared negative: ${newDSquared}. Setting to 0. ${value}, ${timestamp} ${this}`);
}
newDSquared = 0;
}

this.mean = newMean;
this.dSquared = newDSquared;
}
};
