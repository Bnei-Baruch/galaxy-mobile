import 'dart:convert';

enum ChatMessageSender {
  UNKNOWN,
  ACTIVE_USER,
  FRIEND,
}

class ChatMessage {
  String senderId;
  String senderName;
  ChatMessageSender senderType;
  String messageContent;
  int messageTime;

  ChatMessage(
      this.senderId,
      this.senderName,
      this.senderType,
      this.messageContent,
      this.messageTime);

  factory ChatMessage.fromMQTTJson(var json, ChatMessageSender sender, int messageTime) {
    String senderId = json['user']['id'] ?? '';
    String text = json['text'] ?? '';
    String senderName = json['user']['display'] ?? '';
    // UTF8 decoding is required to handle Hebrew.
    String decodedText = utf8.decode(text.runes.toList());
    return ChatMessage(
        senderId,
        senderName,
        sender,
        decodedText,
        messageTime);
  }

  Map<String, dynamic> toMQTTJson() => {
    'user': {
      'id': senderId,
      'role': 'user',
      'display': senderName
    },
    'type': 'client-chat',
    'text': messageContent
  };
}