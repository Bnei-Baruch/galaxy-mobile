
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
  bool unread = true;

  ChatMessage(
      this.senderId,
      this.senderName,
      this.senderType,
      this.messageContent,
      this.messageTime);

  factory ChatMessage.fromMQTTJson(var json, String activeUserId, int messageTime) {
    String senderId = json['user']['id'] ?? '';
    String text = json['text'] ?? '';
    String senderName = json['user']['display'] ?? '';

    return ChatMessage(
        senderId,
        senderName,
        senderId == activeUserId
            ? ChatMessageSender.ACTIVE_USER
            : ChatMessageSender.FRIEND,
        text,
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