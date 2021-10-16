import 'dart:io'; // for exit();
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/src/widgets/framework.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/services/monitoring_data.dart';
import 'package:provider/provider.dart';

Future<SendPort> initIsolate(BuildContext context) async {
  Completer completer = new Completer<SendPort>();
  ReceivePort isolateToMainStream = ReceivePort();

  isolateToMainStream.listen((data) {
    if (data is SendPort) {
      SendPort mainToIsolateStream = data;
      completer.complete(mainToIsolateStream);
    } else {
      Provider.of<MainStore>(context, listen: false)
          .updateMonitor(data.toString());

      //print('[isolateToMainStream] $data');
    }
  });

  Isolate myIsolateInstance =
      await Isolate.spawn(myIsolate, isolateToMainStream.sendPort);
  return completer.future;
}

void myIsolate(SendPort isolateToMainStream) {
  ReceivePort mainToIsolateStream = ReceivePort();
  isolateToMainStream.send(mainToIsolateStream.sendPort);
  MonitoringData monitor = new MonitoringData(isolateToMainStream);

  mainToIsolateStream.listen((data) {
    switch (data["type"]) {
      case "setConnection":
        monitor.setConnection(data["plugin"], data["audioTrack"], data["videoTrack"], data["user"], data["galaxyServer"]); //,
        //data["userExtra"], data["data"]);
        //data["user"]

        break;
      case "start":
        monitor.startMonitor();
        break;
      case "stop":
        monitor.stopMonitor();
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
