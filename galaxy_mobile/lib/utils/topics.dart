
final String USERS_BROADCAST_TOPIC = "galaxy/users/broadcast";

enum TopicType {
  UNKNOWN,
  ROOM_CHAT,
  USERS_BROADCAST,
}

// Class for parsing MQTT topics.
class Topics {
  static final RegExp _roomChatPattern = RegExp(
    r"^galaxy\/room/\d+\/chat");

  static parse(String topic) {
    if (_roomChatPattern.hasMatch(topic)) {
      return TopicType.ROOM_CHAT;
    } else if (topic == USERS_BROADCAST_TOPIC) {
      return TopicType.USERS_BROADCAST;
    } // TODO: add user topic: "galaxy/users/${user.id}"

    return TopicType.UNKNOWN;
  }
}