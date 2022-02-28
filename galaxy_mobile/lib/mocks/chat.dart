import 'dart:async';

import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:galaxy_mobile/viewmodels/chat_view_model.dart';

Timer createPeriodicMockChatMessages(ChatViewModel model, Duration duration) {
  List<ChatMessage> chatMessages = [
    ChatMessage("a", "משה", ChatMessageSender.FRIEND, "שלום חברים", 1644050115),
    ChatMessage("a", "משה", ChatMessageSender.FRIEND, "נתחיל סדנא?", 1644051115),
    ChatMessage("a", "משה", ChatMessageSender.FRIEND, r'''חברים
          מישהו
          כאן? 

          יש פה מישהו?''', 1644051115),
    ChatMessage("b", "boris", ChatMessageSender.FRIEND, "da", 1644062115),
    ChatMessage("c", "יולי", ChatMessageSender.FRIEND, "אנחנו התאספנו כאן to do a workshop עם החברים", 1644063115),
    ChatMessage("me", "yaniv", ChatMessageSender.ACTIVE_USER, "אין עוד מלבדו", 1644074015),
    ChatMessage("me", "yaniv", ChatMessageSender.ACTIVE_USER, "עוד הודעה", 1644084115),
    ChatMessage("b", "boris", ChatMessageSender.FRIEND, "long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long ", 1644089115),
    ChatMessage("a", "משה", ChatMessageSender.FRIEND, r'''line breaks long long long long long long long long
          long long long long long long long long long long
          long long long long long long long long long long
          long long long long long long long long long long
          long long long long long long long long long long long long long long
          long long long long long long long long long long long long long long long
           long long long long long long long long long long long long long long
            long long''', 1644094115),
    ChatMessage("a", "משה", ChatMessageSender.FRIEND, "לחיים", 1644095115),
  ];

  return Timer.periodic(duration, (Timer t) {
    var message = (chatMessages.toList()..shuffle()).first;
    model.addChatMessage(
        ChatMessage(message.senderId, message.senderName, message.senderType, message.messageContent,
            DateTime.now().millisecondsSinceEpoch));
  });
}