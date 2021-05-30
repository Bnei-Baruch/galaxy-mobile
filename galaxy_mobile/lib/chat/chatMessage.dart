import 'package:flutter/material.dart';


class ChatMessage{
  String senderName;
  String messageContent;
  String messageType;
  ChatMessage({
    @required this.senderName,
    @required this.messageContent,
    @required this.messageType});
}