class ChatMessage {
  String senderId;
  String senderName;
  String messageContent;
  String messageType;
  int messageTime;

  ChatMessage(
      this.senderId,
      this.senderName,
      this.messageContent,
      this.messageType,
      this.messageTime);
}