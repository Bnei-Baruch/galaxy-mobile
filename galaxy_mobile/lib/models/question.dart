// TODO: move to JsonSerializable once we upgrade flutter to null safety.
class Question {
  String userName;
  String roomName;
  String content;
  bool askForMe;
  int timestamp;

  Question({this.userName, this.roomName, this.content, this.askForMe, this.timestamp});

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
        userName: json['user']['name'] ?? '',
        roomName: json['user']['galaxyRoom'] ?? '',
        content: json['question']['content'] ?? '',
        askForMe: json['askForMe'] ?? false,
        timestamp: json['timestamp'] ?? 0);
  }
}