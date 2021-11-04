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
final statsNames = ["oneMin", "threeMin", "tenMin"];

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
BuildContext context;
  Plugin pluginHandle;
  MediaStreamTrack localAudioTrack;
  MediaStreamTrack localVideoTrack;
  var miscData = Map<String,dynamic>();
  var storedData = [];
  var scoreData = [];
  var spec = {
    "sample_interval": INITIAL_SAMPLE_INTERVAL,
    "store_interval": INITIAL_STORE_INTERVAL,
    "metrics_whitelist": [],
  };

  Map<String, dynamic> sentData;

  var onStatus;

  MonitoringData(SendPort isolateToMainStream) {
    toApp = isolateToMainStream;
  }

  setConnection(
      BuildContext pluginHandle,
      MediaStreamTrack localAudioTrack,
      MediaStreamTrack localVideoTrack,
      Map<String, dynamic> user,
      String streamingGateway)  {
    // userJsonExtra = userExtra;
    // //userJson = user.toJson();
    // sentData = data;
    this.context = pluginHandle;
    this.localAudioTrack = localAudioTrack;
    this.localVideoTrack = localVideoTrack;
    userJson = user;
    userJson["cpu"] = (Platform.isAndroid ? "Android " : "iOS ") +
        Platform.operatingSystemVersion;

    userJson["ram"] = (SysInfo.getTotalPhysicalMemory()/1000/1000/1000).floor().toString();

    userJson["network"] = "true";
    userJson["streamingGateway"] = streamingGateway;

    userJson["galaxyVersion"] = "1.0.8";

    userJson["title"] = user["givenName"];

    userJson["display"] = user["givenName"];

    userJson["janus"] = "gxy2";//janusGateway;


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
    //send request for stats to app
    // toApp.send({
    //   "type": 'getStat',
    // });
    
  }

  updateLooper() {
    print("monitor updateLooper");
    int counter = 1;
    updateBackend("ff");
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

  monitor_(data) {
    print("monitor data before print");
    print("monitor data " + jsonEncode(data));
    var defaultTimestamp = DateTime
        .now()
        .millisecondsSinceEpoch;
    if (data != null && data["video"] != null && data["audio"] != null) {
      var datas = [];
      var SKIP_REPORTS = [
        "certificate",
        "codec",
        "track",
        "local-candidate",
        "remote-candidate"
      ];
      var getStatsPromises = [];

      var audioReports = {
        "name": "audio",
        "reports": [],
        "timestamp": defaultTimestamp
      };
      data["audio"].forEach((report) {
        // Remove not necessary reports.
        if (!SKIP_REPORTS.contains(report["type"])) {
          if (report["timestamp"] != null) {
            audioReports["timestamp"] = report["timestamp"];
          }
          (audioReports["reports"] as List).add(report);
        }
      });
      datas.add(audioReports);
      getStatsPromises.add(datas);


      var videoReports = {
        "name": "video",
        "reports": [],
        "timestamp": defaultTimestamp
      };
      data["video"].forEach((report) {
        // Remove not necessary reports.
        if (!SKIP_REPORTS.contains(report["type"])) {
          if (report["timestamp"] != null) {
            videoReports["timestamp"] = report["timestamp"];
          }
          (videoReports["reports"] as List).add(report);
        }
      });
      datas.add(videoReports);

      getStatsPromises.add(datas);


      // Missing some important reports. Add them manually.
      var ids = [this.localAudioTrack.id];
      if (this.localVideoTrack != null) {
        ids.add(this.localVideoTrack.id);
      }
      var mediaSourceIds = [];
      var ssrcs = [];

      data["general"].forEach((report) {
        if (ids.contains(report.values["trackIdentifier"])) {
          if (report.values["mediaSourceId"] != null &&
              !mediaSourceIds.contains(report.values["mediaSourceId"])) {
            mediaSourceIds.add(report.values["mediaSourceId"]);
          }
        }
      });
      if (mediaSourceIds.length != null) {
        data["general"].forEach((report) {
          if (mediaSourceIds.contains(report.values["mediaSourceId"])) {
            if (report.values["ssrc"] != null &&
                !ssrcs.contains(report.values["ssrc"])) {
              ssrcs.add(report.values["ssrc"]);
            }
          }
        });
      }
      if (ssrcs.length != null) {
        data["general"].forEach((report) {
          if (ssrcs.contains(report.values["ssrc"]) ||
              mediaSourceIds.contains(report.values["mediaSourceId"]) ||
              ids.contains(report.values["trackIdentifier"])) {
            var kind = report.values["kind"];
            var type = report.type;
            var data = datas.firstWhere((data) => data.name == kind);
            if (data && data.reports) {
              var r =
              (data["reports"] as List).firstWhere((r) => r.type == type);
              if (!r) {
                (data["reports"] as List).add(report);
              }
            }
          }
        });
      }
      getStatsPromises.add(data);
      forEachMonitor(datas, defaultTimestamp);
      // Promise.all(getStatsPromises).then(() => {
      // this.forEachMonitor_(datas, defaultTimestamp);
      // });
      // } else {
      // this.forEachMonitor_([], defaultTimestamp);
      // }
    }
    else
      {
        forEachMonitor([], defaultTimestamp);
      }
  }

  dynamic navigatorConnectionData(var timestamp) {
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

  void updateSpec (whiteList)
  {
    spec = whiteList;
  }
  onIceState(state) {
    this.miscData["iceState"] = state;
  }
  onSlowLink(slowLinkType, lost) {
    var countName = "slow-link-${slowLinkType}";
    var lostName = "slow-link-${slowLinkType}-lost";
    if ((!this.miscData.containsKey(countName))) {
      this.miscData[countName] = 0;
    }
    this.miscData[countName]++;
    if (!(miscData.containsKey(lostName))) {
      this.miscData[lostName] = 0;
    }
    this.miscData[lostName] += lost;
  }

  Map<String,dynamic> getMiscData(var timestamp) {
    var misc =  Map<String,dynamic>.of({"timestamp":timestamp, "type": "misc"});
    misc.addAll(miscData);
    return misc;
  }

  forEachMonitor(List datas, defaultTimestamp) {
    var dataTimestamp =
        (datas != null && datas.length > 0)?  datas[0].timestamp :
            defaultTimestamp;
    // var navigatorConnection = this.navigatorConnectionData(dataTimestamp);
    // if (navigatorConnection) {
    //   datas.add({
    //     "name": "NetworkInformation",
    //     "reports": [navigatorConnection],
    //     "timestamp": dataTimestamp
    //   });
    // }
    var misc = this.getMiscData(dataTimestamp);
    if (misc != null) {
      datas.add({
        "name": "Misc",
        "reports": [misc],
        "timestamp": dataTimestamp
      });
    }
    if (datas.length > 0) {
      this.storedData.add(datas);
    }

    // This is Async callback. Sort stored data.
    this.storedData.sort((a, b) => a[0].timestamp - b[0].timestamp);
    // Throw old stats, STORE_INTERVAL from last timestamp stored.
    var lastTimestamp = this.lastTimestamp();
    if (lastTimestamp >0) {
      this.storedData.removeWhere((data) =>
          data[0]["timestamp"] <= lastTimestamp - this.spec["store_interval"]);
    }
    if (datas.length > 0 /*&& this.onDataCallback*/ &&
        this.storedData.length > 0) {
      //this.onDataCallback(this.storedData[this.storedData.length - 1]);
    }
    this.updateScore();

    var backoff = min(MAX_EXPONENTIAL_BACKOFF_MS,
        FIVE_SECONDS_IN_MS * pow(2, this.fetchErrors));
    if ((lastUpdateTimestamp > 0 &&
                fetchErrors > 0) /* Fetch for the first time */ ||
            (lastTimestamp - this.lastUpdateTimestamp >
                    this.spec[
                        "store_interval"] /* Fetch after STORE_INTERVAL */ &&
                lastTimestamp - this.lastFetchTimestamp >
                    backoff) /* Fetch after errors backoff */
        ) {
      this.updateBackend(/*logToConsole=*/ "");
    }
  }

  getMetricValue(dynamic data, metric, prefix) {
    if (data != null && data is List) {

      Map e = data.firstWhere((e) =>
        metric.startsWith(
        //  e["name"] != null ? "[name:${e["name"]}]" : "[type:${e["type"]}]"
         // "[name:Misc]."
            [prefix, e["name"]!=null ? "[name:${e["name"]}]" : "[type:${e["type"]}]"].where((element) => (element as String).isNotEmpty)
                .join(".")
        )
        ,orElse: ()=>null
      );

      if (e == null) {
        return null;
      }
      return this.getMetricValue(
          e,
          metric,
          [prefix, e["name"]!=null ? "[name:${e["name"]}]" : "[type:${e["type"]}]"].where((element) => (element as String).isNotEmpty)
              .join("."));
    } else if (data != null && data is Map) {
      for(var key  in data.keys)
         {
        if (metric.startsWith("${prefix}.${key}")) {
          final ret = getMetricValue(data[key], metric, "${prefix}.${key}");
          if (ret != null) {
            return ret;
          }
        }
      }
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
      data.removeWhere((e) =>
          (metrics as List).any((m) =>
              m.startsWith([
            prefix,
            e["name"]!= null ? "[name:${e["name"]}]" : "[type:${e["type"]}]"
          ].join("."))));
      data.map((e) => this.filterData(
          e,
          metrics,
          [prefix, e["name"] ? "[name:${e["name"]}]" : "[type:${e["type"]}]"]
              .join(".")));
      return data;
    } else if (data is Map) {
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
    var data = this
        .storedData
        .map((d) => this.filterData(d, this.spec["metrics_whitelist"], ""));
    data.forEach((d) {
      if (d.length>0 && d[0]["timestamp"] !=null) {
        var timestamp = d[0]["timestamp"];
        var lastScoreTimestamp = scoreData.length > 0 ?
            scoreData[scoreData.length - 1][0]["timestamp"]:0;
        if (timestamp != null &&
            (lastScoreTimestamp > 0 || lastScoreTimestamp < timestamp)) {
          this.scoreData.add(d);
        }
      }
    });
    // Remove older then 10 minutes.
    var last = scoreData.isNotEmpty?scoreData[scoreData.length - 1]:null;
    if (last != null && last.length>0 && /* [0] - audio */ last[0]["timestamp"]!=null) {
      var lastTimestamp = last[0]["timestamp"];
      scoreData.removeWhere((d) {
        var timestamp = d[0]["timestamp"];
        return (timestamp > 0) ? (timestamp >= lastTimestamp + FULL_BUCKET):false;
      });
      var input = {
        // Last timestamp.
        "timestamp": [lastTimestamp],
        // Last timestamp values.
        "data": (spec["metrics_whitelist"] as List)
            .map((metric) => [getMetricValue(last, metric, "")]).toList(),
        // Mapping form metric to it's index.
        "index":
        (spec["metrics_whitelist"] as List).asMap(),
        "stats": (spec["metrics_whitelist"] as List).map((metric) {
          print("got inside");
          var stats = [new Stats(), new Stats(), new Stats()];
          var mappedStats = stats.asMap();
              for(var key in mappedStats.keys)
                  {

            var mappedScoreData = this.scoreData.map((d) {
              return [d[0]["timestamp"],
                 this.getMetricValue(d, metric, "")];
            }).toList();
            for(var timestamp in mappedScoreData) {
              switch (key) {
                case 0: // Smallest time bucket.
                  if (lastTimestamp - timestamp[0] > FIRST_BUCKET) {
                    null; // Skipp add.
                  }
                  break;
                case 1: // Medium time bucket.
                  if (lastTimestamp - timestamp[0] > MEDIUM_BUCKET) {
                    null; // Skipp add.
                  }
                  break;
                case 2: // Full time bucket
                  if (lastTimestamp - timestamp[0] > FULL_BUCKET) {
                    null; // Skipp add.
                  }
                  break;
                default:
                  null;
                  break;
              }
               mappedStats[key].add(timestamp[1] ,timestamp[0]);
            }
          }
              return mappedStats;
        }).toList()
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
      if (onStatus != null) {
        var firstTimestamp = scoreData[0][0].timestamp;
        var formula =
            "Score ${values["score"]["view"]} = ${values["score"]["formula"]}";
        // console.log('Connection', formula, values.score.value);
        if (lastTimestamp - firstTimestamp >= MEDIUM_BUCKET) {
          if (values["score"]["value"] < 10) {
            this.onStatus(LINK_STATE_GOOD, formula);
          } else if (values["score"]["value"] < 100) {
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

  int lastTimestamp() {
    return (this.storedData.length > 0 &&
            this.storedData.elementAt(this.storedData.length - 1)!=null &&
            this.storedData.elementAt(this.storedData.length - 1).length>0)
        ? this.storedData[this.storedData.length - 1][0]["timestamp"]
        : 0;
  }

  updateBackend(String data) async {
    print("monitor updateBackend");
    //this.userJson["network"] = (await Connectivity().checkConnectivity()).toString();
    //  userJson["diskFree"] = (await DiskSpace.getFreeDiskSpace).toString();
    var datatoSend = storedData.map((e) => filterData(e, spec["metrics_whitelist"], ""));

    var data = {
      "user": this.userJson,
      "data": [[{"name": "audio", "reports": [], "timestamp": DateTime.now().millisecondsSinceEpoch}, {"name": "video", "reports": [], "timestamp": DateTime.now().millisecondsSinceEpoch},(datatoSend.first as List).first ]],
    };
    //{"name": "Misc", "reports": [], "timestamp": DateTime.now().millisecondsSinceEpoch}
    // var user_monitor = await Utils.parseJson("user_monitor_example.json");
    // var data_monitor = await Utils.parseJson("monitor_data.json");
    // Map<String, dynamic> data_exp = {
    //   "user": user_monitor,
    //   "data": data_monitor
    // };

    String data_to_send = json.encode(data);
    toApp.send({
          "type": 'updateBackend',
          "data": data_to_send,
        });

    //Api().updateMonitor(data.toString());
  }

  void setReport(data) {
    monitor_(data);
  }
}

class Stats {
  int mean;

  int dSquared;

  int length;

  int maxAddedTimestamp;

  int maxRemovedTimestamp;

  int numAdds;

  int numRemoves;

  int numEmptyRemoves;

  Stats() {
    this.mean = 0;
    this.dSquared = 0;
    this.length = 0;
    this.maxAddedTimestamp = 0;
    this.maxRemovedTimestamp = 0;
    this.numAdds = 0;
    this.numRemoves = 0;
    this.numEmptyRemoves = 0;
  }

  add(dynamic value, var timestamp) {
    if (value == null || value is String) {
// May be string value. Ignore.
      return;
    }

    this.numAdds +=1;
    if (timestamp > this.maxAddedTimestamp) {
      this.maxAddedTimestamp = timestamp;
    } else {
      print(
          "Expecting to add only new values, old timestamp: ${timestamp} found, max ${this.maxAddedTimestamp}.");
    }
    this.length++;

    var meanIncrement = (value - this.mean) / this.length;
    var newMean = this.mean + meanIncrement;

    var dSquaredIncrement = (value - newMean) * (value - this.mean);
    var newDSquared =
        (this.dSquared * (this.length - 1) + dSquaredIncrement) / this.length;
    if (newDSquared.isNaN) {
      print(
          "add newDSquared $newDSquared, $this.dSquared, $this.length, $dSquaredIncrement");
    }
    if (newDSquared < 0) {
// Correcting float inaccuracy.
      if (newDSquared < -0.00001) {
        print(
            "Add: newDSquared negative: ${newDSquared}. Setting to 0. ${value}, ${timestamp} ${this}");
      }
      newDSquared = 0;
    }

    this.mean = newMean.toInt();
    this.dSquared = newDSquared.toInt();
  }

  remove(double value, var timestamp) {
    if (value.isNaN || !value.isFinite) {
// May be string value. Ignore.
      return;
    }
    if (timestamp > this.maxRemovedTimestamp) {
      this.maxRemovedTimestamp = timestamp;
    } else {
      print(
          "Expecting to remove only new values, old timestamp: ${timestamp} found, max ${this.maxRemovedTimestamp}.");
    }
    if (this.length <= 1) {
      if (this.length == 1) {
        this.numRemoves++;
      } else {
        this.numEmptyRemoves++;
      }
      print("Empty stats (${value}, ${timestamp}, ${this}).");
      this.mean = 0;
      this.dSquared = 0;
      this.length = 0;
      return;
    }
    this.numRemoves++;
    this.length--;

    var meanIncrement = (this.mean - value) / this.length;
    var newMean = this.mean + meanIncrement;

    var dSquaredIncrement = (newMean - value) * (value - this.mean);
    var newDSquared =
        (this.dSquared * (this.length + 1) + dSquaredIncrement) / this.length;
    if (newDSquared.isNaN) {
      print(
          "remove $newDSquared  $newDSquared, $this.dSquared, $this.length, $dSquaredIncrement");
    }
    if (newDSquared < 0) {
// Correcting float inaccuracy.
      if (newDSquared < -0.00001) {
        print(
            "Remove: newDSquared negative: ${newDSquared}. Setting to 0. ${value}, ${timestamp} ${this}");
      }
      newDSquared = 0;
    }

    this.mean = newMean.toInt();
    this.dSquared = newDSquared.toInt();
  }
}



List audioVideoScore(var audioVideo) {
  if (audioVideo == null) {
    return [0, ""];
  }
  var score = 0;
  var formula = "";
  if (audioVideo["jitter"] !=null && audioVideo["jitter"]["score"]["value"] > 0) {
    score += 1000 * audioVideo["jitter"]["score"]["value"];
    formula += "1000*jitter(${audioVideo["jitter"]["score"]["value"]})";
  }
  if (audioVideo["packetsLost"] !=null && audioVideo["packetsLost"]["score"]["value"] >0) {
    score += audioVideo["packetsLost"]["score"]["value"];
    formula += " + packet lost(${audioVideo["packetsLost"]["score"]["value"]})";
  }
  if ( audioVideo["roundTripTime"] !=null && audioVideo["roundTripTime"]["score"]["value"] >0 ) {
    score += 100 * audioVideo["roundTripTime"]["score"]["value"];
    formula += " + 100*rTT(${audioVideo["roundTripTime"]["score"]["value"]})";
  }
  return [score, formula];
}

String sinceTimestamp(ms, now) {
  var pad = (double number, int size) {
    String s = number.toString();
    while (s.length < (size ?? 2)) {
      s = "0" + s;
    }
    return s;
  };
  var loginDate = DateTime.fromMicrosecondsSinceEpoch(ms).millisecondsSinceEpoch;
  var diff = now - loginDate;
  var minutes = pad(((diff / (1000 * 60)) % 60), 2);
  var hours = (diff / (1000 * 3600));
  return "${hours}h:${minutes}m";
}

Map dataValues(var data, var now) {
  var values = {};
  if (data["timestamp"]!=null && data["timestamp"].length>0) {
    values = {
      "value": data["timestamp"][0],
      "view": sinceTimestamp(data["timestamp"][0], now)
    };
  }
  if (data["index"] != null) {
    (data["index"] as Map).forEach((key, metric) {
      var metricField = (metric as String).contains("Misc")
          ? "misc"
          : (metric as String).contains("video")
              ? "video"
              : "audio";
      if (values.containsKey(metricField)) {
        values[metricField] = {};
      }
      var metricName = (metric.split(".") as List).last;
      var metricNames = [
        ["slow-link-receiving", "slowLink"],
        ["slow-link-receiving-lost", "slowLinkLost"],
      ];
      if (metricNames.contains(metricName)) {
        metricName = metricNames[metricName];
      }
      values[metricField]  = {};
      values[metricField][metricName] = {};

      var value = data["data"][key][0];
      values[metricField][metricName] = { "view": value};
      var metricScore = 0;
      if (value != null) {
        data["stats"][key].forEach((statsIndex,stats ) {
          var stdev = sqrt(stats.dSquared);
          values[metricField][metricName][statsNames[statsIndex]] = {
            "mean": {"value": stats.mean, "view": (stats.mean)},
            "stdev": {"value": stdev, "view": (stdev)},
            "length": {"value": stats.length, "view": (stats.length)},
          };
        });
        if ((values[metricField][metricName]["oneMin"] as Map).isNotEmpty &&
            (values[metricField][metricName]["threeMin"] as Map).isNotEmpty) {
          metricScore = values[metricField][metricName]["oneMin"]["mean"]["value"] -
              values[metricField][metricName]["threeMin"]["mean"]["value"];
        }
      }
      values[metricField][metricName]["score"] = {
        "value": metricScore,
        "view": (metricScore)
      };
    });
  }
  var scoreFormulaAudio = audioVideoScore(values["audio"]);
  var scoreFormulaVideo = audioVideoScore(values["video"]);
  scoreFormulaAudio.first += scoreFormulaVideo.first;
  scoreFormulaAudio.last =
      "Audio: ${scoreFormulaAudio.last} + Video: ${scoreFormulaVideo.last}";
  if (values["misc"] != null &&
      values["misc"]["iceState"] != null &&
      (values["misc"]["iceState"] as Map)["view"] !=null) {
    if (!["checking", "completed", "connected"]
        .contains((values["misc"]["iceState"] as Map)["view"])) {
      scoreFormulaAudio.first +=
          100000; // Ice state disconnected or not connected yet. Slow user!
      scoreFormulaAudio.last += " + 100K iceState";
    }
  }
  if (values["misc"] != null && values["misc"]["slowLink"]!=null) {
    scoreFormulaAudio.first += values["misc"]["slowLink"]["score"]["value"] * 100;
    scoreFormulaAudio.last +=
        " + 100*slowLink(${values["misc"]["slowLink"]["score"]["value"]})";
  }
  if (values["misc"] != null && values["misc"]["slowLinkLost"] != null) {
    scoreFormulaAudio.first +=
        values["misc"]["slowLinkLost"]["score"]["value"] * 10;
    scoreFormulaAudio.last +=
        " + 10*slowLinkLost(${values["misc"]["slowLinkLost"]["score"]["value"]})";
  }
  values["score"] = {
    "value": scoreFormulaAudio.first,
    "view": scoreFormulaAudio.last
  };
  return values;
}
