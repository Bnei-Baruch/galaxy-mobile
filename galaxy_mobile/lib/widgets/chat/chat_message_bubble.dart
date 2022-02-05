import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:galaxy_mobile/utils/utils.dart';


// TODO: add tip styling for first message.
// TODO: move colors to theme.
// TODO: handle line breaks (\n) properly.
// TODO: show "read more"
// TODO: handle links properly.

const int COLOR_RANGE = 16777216;
const int BRIGHTNESS = 0x222222;

class ChatMessageBubble extends StatelessWidget {
  final String activeUserId;
  // Whether this bubble is the first in the thread.
  // A thread is a collection of messages from the same user.
  final bool isFirstInThread;
  final ChatMessage chatMessage;

  ChatMessageBubble({this.activeUserId, this.isFirstInThread = true, @required this.chatMessage});

  Color _getUserNameColor() {
    final hashInColorRange = (chatMessage.senderName.hashCode.abs() % COLOR_RANGE) + BRIGHTNESS;
    final red = ((hashInColorRange & 0xFF0000) >> 16);
    final green = ((hashInColorRange & 0xFF00) >> 8);
    final blue = ((hashInColorRange & 0xFF));
    final color = Color.fromRGBO(red, green, blue, 1);
    return color;
  }

  BorderRadius _getBorderRadius(bool isMessageFromActiveUser, Radius radius) {
    if (!isFirstInThread) {
      return BorderRadius.all(radius);
    }

    return isMessageFromActiveUser
        ? BorderRadius.only(topLeft: radius,
        bottomLeft: radius,
        bottomRight: radius)
        : BorderRadius.only(topRight: radius,
        bottomLeft: radius,
        bottomRight: radius);
  }

  Widget build(BuildContext context) {
    // TODO: this is the prod version, keep this.
    // bool isMessageFromActiveUser = chatMessage.senderId == activeUserId;
    // TODO: remove, for testing only.
    bool isMessageFromActiveUser = chatMessage.senderId == "me";

    bool isContentRTL = Utils.isRTLString(chatMessage.messageContent);
    ui.TextDirection textDirection = isContentRTL
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
    ui.TextAlign textAlign = isContentRTL
        ? ui.TextAlign.right
        : ui.TextAlign.left;

    Widget message = Container(
      decoration: BoxDecoration(
          color: isMessageFromActiveUser ? Color(0xFF265B4C) : Color(0xFF232C32),
          borderRadius: _getBorderRadius(isMessageFromActiveUser, Radius.circular(10))
      ),
      constraints: BoxConstraints.loose(MediaQuery.of(context).size * 0.8),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chatMessage.senderName, style: TextStyle(color: _getUserNameColor())),
            Text(
              chatMessage.messageContent,
              softWrap: true,
              textDirection: textDirection,
            ),
            Text(
                Utils.formatTimestampAsDate(chatMessage.messageTime, "hh:mm"),
                style: TextStyle(color: Colors.white.withOpacity(0.5))
            )
          ]),
    );

    return Container(
      margin: EdgeInsets.only(top: isFirstInThread ? 10 : 2),
      child: Row(
        children: <Widget>[
          isMessageFromActiveUser ? Spacer() : message,
          isMessageFromActiveUser ? message : Spacer()
        ]
      ),
    );
  }
}