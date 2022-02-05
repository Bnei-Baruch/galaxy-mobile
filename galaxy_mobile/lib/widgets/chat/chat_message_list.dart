
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/chat_message.dart';

import 'chat_message_bubble.dart';

// TODO: add keys
// TODO: show fab icon showing new messages below
// TODO: control height from where we won't scroll down on new messages.
// TODO: scroll to bottom on first render.
// TODO: keep scroll position when we return to the list.
// TODO: make sure scroll is kept with new messages.
// TODO: show initial message disclaimer.
class ChatMessageList extends StatelessWidget {
  final String activeUserId;
  final List<ChatMessage> chatMessages;

  ChatMessageList({this.activeUserId, @required this.chatMessages});

  Widget build(BuildContext buildContext) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: ListView.builder(
        itemCount: chatMessages.length,
        itemBuilder: (BuildContext context, int index) {
          return ChatMessageBubble(
            activeUserId: activeUserId,
            isFirstInThread: index == 0 || (chatMessages[index - 1].senderId != chatMessages[index].senderId),
            chatMessage: chatMessages[index]);
        },
      )
    );
  }
}
