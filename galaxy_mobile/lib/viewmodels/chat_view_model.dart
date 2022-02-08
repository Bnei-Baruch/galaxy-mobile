import 'package:flutter/foundation.dart';
import 'package:galaxy_mobile/models/chat_message.dart';

// TODO: add unread messages
// TODO: add chat visibility
class ChatViewModel extends ChangeNotifier {
  List<ChatMessage> _chatMessages = [];

  get chatMessages => _chatMessages;

  void addChatMessage(ChatMessage message) {
    _chatMessages = [..._chatMessages, message];
    notifyListeners();
  }
}