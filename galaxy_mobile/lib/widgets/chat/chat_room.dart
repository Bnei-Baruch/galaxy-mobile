
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:galaxy_mobile/viewmodels/chat_view_model.dart';
import 'package:galaxy_mobile/widgets/chat/chat_message_bubble.dart';
import 'package:galaxy_mobile/widgets/chat/send_chat_message_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logs/flutter_logs.dart';

// TODO: add keys
// TODO: show fab icon showing new messages below
// TODO: * control height from where we won't scroll down on new messages.
// TODO: scroll to bottom on first render, and new messages given * above.
// TODO: make sure scroll is kept with new messages.
class ChatRoom extends StatelessWidget {
  Widget build(BuildContext context) {
    // TODO: For testing
    // List<ChatMessage> chatMessages = [
    //   ChatMessage("a", "משה", ChatMessageSender.FRIEND, "שלום חברים", 1644050115),
    //   ChatMessage("a", "משה", ChatMessageSender.FRIEND, "נתחיל סדנא?", 1644051115),
    //   ChatMessage("a", "משה", ChatMessageSender.FRIEND, r'''חברים
    //       מישהו
    //       כאן?
    //
    //       יש פה מישהו?''', 1644051115),
    //   ChatMessage("b", "boris", ChatMessageSender.FRIEND, "da", 1644062115),
    //   ChatMessage("c", "יולי", ChatMessageSender.FRIEND, "אנחנו התאספנו כאן to do a workshop עם החברים", 1644063115),
    //   ChatMessage("me", "yaniv", ChatMessageSender.ACTIVE_USER, "אין עוד מלבדו", 1644074015),
    //   ChatMessage("me", "yaniv", ChatMessageSender.ACTIVE_USER, "עוד הודעה", 1644084115),
    //   ChatMessage("b", "boris", ChatMessageSender.FRIEND, "long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long ", 1644089115),
    //   ChatMessage("a", "משה", ChatMessageSender.FRIEND, r'''line breaks long long long long long long long long
    //       long long long long long long long long long long
    //       long long long long long long long long long long
    //       long long long long long long long long long long
    //       long long long long long long long long long long long long long long
    //       long long long long long long long long long long long long long long long
    //        long long long long long long long long long long long long long long
    //         long long''', 1644094115),
    //   ChatMessage("a", "משה", ChatMessageSender.FRIEND, "לחיים", 1644095115),
    ];
    List<ChatMessage> chatMessages = context.select((ChatViewModel model) => model.chatMessages);

    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        // TODO: This pushes just the message bar up, but not the list itself. It should push it up when it's at the bottom
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: ListView.builder(
                itemCount: chatMessages.length + 1, // + 1 for initial info message.
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(6))
                      ),
                      padding: EdgeInsets.all(10.0),
                      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

                      child: Text('virtual_chat.msgRoomInfo'.tr(),
                        style: TextStyle(color: Colors.black))
                    );
                  }
                  // Chat message start at index 1.
                  return ChatMessageBubble(
                      isFirstInThread: index == 1
                          || (chatMessages[index - 2].senderId != chatMessages[index - 1].senderId),
                      chatMessage: chatMessages[index - 1]);
                },
              )
            )
          ),
          SendChatMessageBar()
        ]
      )
    );
  }
}
