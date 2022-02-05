import 'package:flutter/material.dart';

// TODO: delete this as it is in models folder..
class ChatMessage{
  String senderName;
  String messageContent;
  String messageType;

  ChatMessage(String sender, String content, String type)
  {
    senderName = sender;
    messageContent = content;
    messageType = type;
  }
}