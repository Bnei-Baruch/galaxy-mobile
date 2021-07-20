import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:galaxy_mobile/chat/chatMessage.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/services/keycloak.dart';

import 'dart:convert';

class Chat extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<Chat> {
  final inputFieldController = TextEditingController();

  bool isFirst = true;
  int _activeRoomId;

  final _controller = ScrollController();
  User _activeUser;

  void update() { setState(() {}); }

  void handleMsg(String msgPayload) {
    FlutterLogs.logInfo(
        "Chat", "handleMsg", "Received message: $msgPayload");
    // try {
    //   var jsonCmd = JsonDecoder().convert(msgPayload);
    //   if (jsonCmd["type"] == "client-chat") {
    //     setState(() {
    //       context.read<MainStore>().addChatMessage(ChatMessage(
    //           senderName: jsonCmd["user"]["givenName"],
    //           messageContent: jsonCmd["msg"],
    //           messageType: "receiver"));
    //       _controller
    //           .jumpTo(_controller.position.maxScrollExtent);
    //     });
    //   }
    // } on FormatException catch (e) {
    //   FlutterLogs.logError("Chat", "handleMsg",
    //       "The provided string is not valid JSON: ${e.toString()}");
    // }
  }

  @override
  Widget build(BuildContext context) {
    final mqttClient = context.read<MQTTClient>();
    context.read<MainStore>().setChatUpdater(() => update());
    if (isFirst) {
      isFirst = false;
      mqttClient.subscribe("galaxy/room/${_activeRoomId.toString()}/chat");
      mqttClient.addOnMsgReceivedCallback((msgPayload) =>
          handleMsg(msgPayload));
    }

    final activeRoom = context.select((MainStore s) => s.activeRoom);
    _activeRoomId = activeRoom.room;
    _activeUser = context.read<MainStore>().activeUser;

    return WillPopScope(
        onWillPop: ()
    {
      dispose();
      Navigator.of(context).pop(true);
      return;
    },
    child: Scaffold(
        appBar: AppBar(title: Text('chat'.tr())),
        body: LayoutBuilder(builder:
            (BuildContext context, BoxConstraints viewportConstraints) {
          return Stack(children: <Widget>[
            SingleChildScrollView(
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: viewportConstraints.maxHeight),
                    child: Container(
                        margin: EdgeInsets.only(top: 10, bottom: 50),
                        alignment: Alignment.topCenter,
                        child: ListView.builder(
                            controller: _controller,
                            itemCount: context.read<MainStore>()
                                .getChatMessages().length,
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            padding: EdgeInsets.only(top: 10, bottom: 10),
                            physics: NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Row(children: <Widget>[
                                Container(
                                    constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.3),
                                    padding: EdgeInsets.only(
                                        left: 14, right: 14, top: 0, bottom: 0),
                                    child: Text(context.read<MainStore>()
                                        .getChatMessages()[index].senderName,
                                        style: TextStyle(fontSize: 15))),
                                Container(
                                    constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.67),
                                    padding: EdgeInsets.only(
                                        left: 14,
                                        right: 14,
                                        top: 10,
                                        bottom: 10),
                                    child: Align(
                                        alignment:
                                        context.read<MainStore>()
                                            .getChatMessages()[index]
                                            .messageType ==
                                                    "receiver"
                                                ? Alignment.topLeft
                                                : Alignment.topRight,
                                        child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              color:
                                              context.read<MainStore>()
                                                  .getChatMessages()[index]
                                                  .messageType ==
                                                          "receiver"
                                                      ? Colors.blue
                                                      : Colors.lightGreen,
                                            ),
                                            padding: EdgeInsets.all(16),
                                            child: Text(
                                                context.read<MainStore>()
                                                    .getChatMessages()[index]
                                                    .messageContent,
                                                style:
                                                    TextStyle(fontSize: 15)))))
                              ]);
                            })))),
            Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                    padding: EdgeInsets.only(left: 10, bottom: 10, top: 10),
                    height: 60,
                    width: double.infinity,
                    color: Colors.white,
                    child: Row(children: <Widget>[
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: inputFieldController,
                          style: TextStyle(color: Colors.black54),
                          decoration: InputDecoration(
                              hintText: "Write to ten...",
                              hintStyle: TextStyle(color: Colors.black54),
                              border: InputBorder.none),
                        ),
                      ),
                      SizedBox(width: 15),
                      FloatingActionButton(
                          onPressed: () {
                            // _controller
                            //     .animateTo(
                            //     _controller.position.maxScrollExtent,
                            //     duration: new Duration(milliseconds: 200),
                            //     curve: Curves.easeOut);
                            // },


                            // {
                            //   "ack":false,
                            //   "textroom":"message",
                            //   "transaction":"SnBxXo2uOJdy",
                            //   "room":1051,
                            //   "text":
                            //    {
                            //      "user":
                            //        {
                            //          "id":"3e7d1f8f-e530-4169-be04-6856fc5a2710",
                            //          "role":"user",
                            //          "display":"Kirill Rogachevsky"
                            //        },
                            //        "type":"chat",
                            //        "text":"uuu"
                            //     }
                            // }

                            var message = {};
                            message["ack"] = false;
                            message["textroom"] = "message";
                            message["transaction"] = "";
                            message["room"] = _activeRoomId;
                            message["text"] = "{\"user\":${_activeUser.toChatString()},\"type\":\"chat\",\"text\":\"${inputFieldController.text}\"}";

                            FlutterLogs.logInfo("chat", "send", "message: ${message.toString()}");
                            mqttClient.send("galaxy/room/${_activeRoomId.toString()}/chat",
                                JsonEncoder().convert(message));

                            inputFieldController.text = "";
                          },
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                          backgroundColor: Colors.blue,
                          elevation: 0)
                    ])
                )
            )
          ]);
        })
    ));
  }

  @override
  void dispose() {
    inputFieldController.dispose();
    context.read<MainStore>().setChatUpdater(() => null);
    super.dispose();
  }
}