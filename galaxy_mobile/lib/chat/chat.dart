import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/mqttClient.dart';
import 'package:galaxy_mobile/chat/chatMessage.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/screens/dashboard/dashboard.dart';
import 'package:provider/provider.dart';


class Chat extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<Chat> {
  final inputFieldController = TextEditingController();
  List<ChatMessage> messages = [];

  MQTTClient _mqttClient;

  @override
  Widget build(BuildContext context) {
    final mainStore = context.read<MainStore>();
    final mqttClient = context.read<MQTTClient>();

    return Scaffold(
        appBar: AppBar(
          title: Text("Ten Chat"),
        ),
        body: Stack(
          children: <Widget>[
            Container(
              margin: EdgeInsets.symmetric(vertical: 0.0),
              // height: 500.0,
              alignment: Alignment.topCenter,
              child:
                  ListView.builder(
                    itemCount: messages.length,
                    shrinkWrap: true,
                    scrollDirection: Axis.vertical,
                    padding: EdgeInsets.only(top: 10,bottom: 10),
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return Row(
                          children: <Widget>[
                            SizedBox(width: 50),
                            Text(messages[index].senderName, style: TextStyle(fontSize: 15),),
                            Text(": ", style: TextStyle(fontSize: 15),),
                            Container(padding: EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
                              child: Align(
                                  alignment: (messages[index].messageType == "receiver" ?
                                  Alignment.topLeft : Alignment.topRight),
                                  child: Container(
                                      decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          color: (messages[index].messageType  == "receiver" ?
                                          Colors.blue : Colors.lightGreen),
                                      ),
                                  padding: EdgeInsets.all(16),
                                  child: Text(messages[index].messageContent,
                                  style: TextStyle(fontSize: 15),),
                              ),
                            )
                            )
                        ]
                      );
                    },
                  ),



              // ListView(
              //   scrollDirection: Axis.vertical,
              //   children: <Widget>[
              //     Container(
              //       height: 160.0,
              //       color: Colors.red,
              //     ),
              //     Container(
              //       height: 160.0,
              //       color: Colors.blue,
              //     ),
              //     Container(
              //       height: 160.0,
              //       color: Colors.green,
              //     ),
              //     Container(
              //       width: 160.0,
              //       color: Colors.yellow,
              //     ),
              //     Container(
              //       height: 160.0,
              //       color: Colors.orange,
              //     ),
              //   ],
              // ),
            ),
        //     ]
        // ),


        //     ListView.builder(
        //       itemCount: messages.length,
        //       shrinkWrap: true,
        //       scrollDirection: Axis.vertical,
        //       padding: EdgeInsets.only(top: 10,bottom: 10),
        //       physics: NeverScrollableScrollPhysics(),
        //       itemBuilder: (context, index) {
        //         return Row(
        //             children: <Widget>[
        //               SizedBox(width: 50),
        //               Text(messages[index].senderName, style: TextStyle(fontSize: 15),),
        //               Text(": ", style: TextStyle(fontSize: 15),),
        //               Container(padding: EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
        //                 child: Align(
        //                     alignment: (messages[index].messageType == "receiver" ?
        //                     Alignment.topLeft : Alignment.topRight),
        //                     child: Container(
        //                         decoration: BoxDecoration(
        //                             borderRadius: BorderRadius.circular(20),
        //                             color: (messages[index].messageType  == "receiver" ?
        //                             Colors.blue : Colors.lightGreen),
        //                         ),
        //                     padding: EdgeInsets.all(16),
        //                     child: Text(messages[index].messageContent,
        //                     style: TextStyle(fontSize: 15),),
        //                 ),
        //               )
        //               )
        //           ]
        //         );
        //       },
        //     ),
        //
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: EdgeInsets.only(left: 10,bottom: 10,top: 10),
                height: 60,
                width: double.infinity,
                color: Colors.white,
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: (){
                      },
                      child: Container(
                        height: 30,
                        width: 30,
                        decoration: BoxDecoration(
                          color: Colors.lightBlue,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(Icons.add, color: Colors.white, size: 20, ),
                      ),
                    ),
                    SizedBox(width: 15,),
                    Expanded(
                      child: TextField(
                          controller: inputFieldController,
                          style: TextStyle(color: Colors.black54),
                          decoration: InputDecoration(
                            hintText: "Write to ten...",
                            hintStyle: TextStyle(color: Colors.black54),
                            border: InputBorder.none
                        ),
                      ),
                    ),
                    SizedBox(width: 15,),
                    FloatingActionButton(
                      onPressed: () => setState(() =>
                          messages.add(ChatMessage(
                              senderName: mainStore.activeUser.name,
                              messageContent: inputFieldController.text,
                              messageType: "receiver"))),

                      // onPressed: (){
                      //   messages.add(ChatMessage(messageContent:
                      //   inputFieldController.text, messageType: "receiver"));
                      //   // return showDialog(
                      //   //   context: context,
                      //   //   builder: (context) {
                      //   //     return AlertDialog(
                      //   //       // Retrieve the text the user has entered by using the
                      //   //       // TextEditingController.
                      //   //       content: Text(inputFieldController.text),
                      //   //     );
                      //   //   },
                      //   // );
                      //   // print('Sending: $inputFieldController.text ');
                      // },
                      child: Icon(Icons.send,color: Colors.white,size: 18,),
                      backgroundColor: Colors.blue,
                      elevation: 0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }

  @override
  void dispose() {
    inputFieldController.dispose();
    super.dispose();
  }
}