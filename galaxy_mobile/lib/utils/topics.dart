enum TopicType {
  UNKNOWN,
  ROOM_CHAT,
}

// Class for parsing MQTT topics.
class Topics {
  static final RegExp _roomChatPattern = RegExp(
    r"^galaxy\/room/\d+\/chat");

  static parse(String topic) {
    if (_roomChatPattern.hasMatch(topic)) {
      return TopicType.ROOM_CHAT;
    }

    return TopicType.UNKNOWN;
  }
}