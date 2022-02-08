import 'package:flutter/foundation.dart';
import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:flutter_logs/flutter_logs.dart';

// TODO: add unread messages
// TODO: add chat visibility
typedef OnNewMessageCallback = bool Function(ChatMessage);

class ChatViewModel extends ChangeNotifier {
  List<ChatMessage> _chatMessages = [];
  OnNewMessageCallback _onNewMessageCallback;

  get chatMessages => _chatMessages;

  get canPublishNewMessage => _onNewMessageCallback != null;

  void addChatMessage(ChatMessage message) {
    _chatMessages = [..._chatMessages, message];
    // We sort the messages since there could be a race between message times
    // and when they were added.
    _chatMessages.sort((a, b) => a.messageTime.compareTo(b.messageTime));
    notifyListeners();
  }

  void publishNewChatMessage(ChatMessage message) {
    if (!canPublishNewMessage) {
      FlutterLogs.logError(
          "ChatViewModel",
          "publishNewChatMessage",
          "Tried to publish new chat message but onNewMessageCallback is not set.");
      return;
    }

    _onNewMessageCallback(message);
    //addChatMessage(message);
  }

  void setOnNewMessageCallback(OnNewMessageCallback callback) {
    _onNewMessageCallback = callback;
    notifyListeners();
  }
}