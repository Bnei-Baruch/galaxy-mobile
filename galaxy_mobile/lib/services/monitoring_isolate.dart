import 'dart:io'; // for exit();
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:galaxy_mobile/models/main_store.dart';
import 'package:galaxy_mobile/services/monitoring_data.dart';
import 'package:provider/provider.dart';

Future<List> initIsolate(BuildContext context) async {
  Completer completer = new Completer<List>();
  ReceivePort isolateToMainStream = ReceivePort();
  Isolate myIsolateInstance =
  await Isolate.spawn(myIsolate, isolateToMainStream.sendPort);

  isolateToMainStream.listen((data)  {
    if (data is SendPort) {
      SendPort mainToIsolateStream = data;
      completer.complete([myIsolateInstance ,mainToIsolateStream]);
    } else {
      switch (data["type"]) {
        case "updateBackend":
          Provider.of<MainStore>(context, listen: false)
              .updateMonitor(data["data"].toString());
          break;
        case "getStat":
           Provider.of<MainStore>(context, listen: false).getStats();

          break;
        case "updateSignal":
          Provider.of<MainStore>(context, listen: false).setSignal(data["data"]);
          break;
      }
      //print('[isolateToMainStream] $data');
    }
  });


  return completer.future;
}

void myIsolate(SendPort isolateToMainStream) {
  ReceivePort mainToIsolateStream = ReceivePort();
  isolateToMainStream.send(mainToIsolateStream.sendPort);
  MonitoringData monitor = new MonitoringData(isolateToMainStream);

  mainToIsolateStream.listen((data) {
    switch (data["type"]) {
      case "setConnection":
        monitor.setConnection(null, null, null, data["user"], data["galaxyServer"],data["janus"],data["version"],data["network"]); //,
        //data["userExtra"], data["data"]);
        //data["user"]

        break;
      case "start":
        monitor.startMonitor();
        break;
      case "stop":
        monitor.stopMonitor();
        break;
      case "report":
        monitor.setReport(data["value"]);
        break;
      case "slowLink":
        monitor.onSlowLink(data["direction"], data["lost"]);
        break;
      case "iceState":
        monitor.onIceState(data["state"]);
        break;
      case "updateSpec":
        monitor.updateSpec(data["spec"]);
        break;
      default:
        print('[mainToIsolateStream] $data');
    }
  });

  //isolateToMainStream.send('This is from myIsolate()');
}

//
// void main() async {
//   SendPort mainToIsolateStream = await initIsolate();
//   mainToIsolateStream.send('This is from main()');
// }
