
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/widgets/chat/chat_message_list.dart';
import 'package:galaxy_mobile/widgets/chat/send_chat_message_bar.dart';
import 'package:galaxy_mobile/models/chat_message.dart';

import 'chat_message_bubble.dart';

// TODO: get messages / active user id
class ChatRoom extends StatelessWidget {
  Widget build(BuildContext buildContext) {

    List<ChatMessage> chatMessages = [
      ChatMessage("a", "משה", "שלום חברים", "", 1644050115),
      ChatMessage("a", "משה", "נתחיל סדנא?", "", 1644051115),
      ChatMessage("a", "משה", r'''חברים
          מישהו
          כאן?
          
          יש פה מישהו?''', "", 1644051115),
      ChatMessage("b", "boris", "da", "", 1644062115),
      ChatMessage("c", "יולי", "אנחנו התאספנו כאן to do a workshop עם החברים", "", 1644063115),
      ChatMessage("me", "yaniv", "אין עוד מלבדו", "", 1644074015),
      ChatMessage("me", "yaniv", "עוד הודעה", "", 1644084115),
      ChatMessage("b", "boris", "long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long ", "", 1644089115),
      ChatMessage("a", "משה", r'''line breaks long long long long long long long long 
          long long long long long long long long long long 
          long long long long long long long long long long 
          long long long long long long long long long long 
          long long long long long long long long long long long long long long 
          long long long long long long long long long long long long long long long
           long long long long long long long long long long long long long long
            long long''', "", 1644094115),
      ChatMessage("a", "משה", "לחיים", "", 1644095115),
    ];

    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        // TODO: This pushes just the message bar up, but not the list itself. It should push it up when it's at the bottom
        bottom: MediaQuery.of(buildContext).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Expanded(child: ChatMessageList(activeUserId: "me", chatMessages: chatMessages)),
          SendChatMessageBar()
        ]
      )
    );
  }
}
