import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:galaxy_mobile/utils/utils.dart';


// TODO: have color buckets for possible user names, that will make it visible
// against the background.
// TODO: show "read more" for long messages.
// TODO: handle links properly.

const int COLOR_RANGE = 16777216;
const int BRIGHTNESS = 0x222222;

const Color ACTIVE_USER_USERNAME_COLOR = Color(0xFF92B6D1);
const Color ACTIVE_USER_BUBBLE_BACKGROUND = Color(0xFF00488B);
const Color FRIEND_BUBBLE_BACKGROUND = Color(0xFF232C32);

class ChatMessageBubble extends StatelessWidget {
  // Whether this bubble is the first in the thread.
  // A thread is a collection of messages from the same user.
  final bool isFirstInThread;
  final ChatMessage chatMessage;

  ChatMessageBubble({this.isFirstInThread = true, @required this.chatMessage});

  // Randomly generate a color from the hash of the username.
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
    bool isMessageFromActiveUser = chatMessage.senderType == ChatMessageSender.ACTIVE_USER;

    bool isContentRTL = Utils.isRTLString(chatMessage.messageContent);
    ui.TextDirection textDirection = isContentRTL
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
    ui.TextAlign textAlign = isContentRTL
        ? ui.TextAlign.right
        : ui.TextAlign.left;

    Widget message =
      CustomPaint(
        painter: BubblePainter(
          color: isMessageFromActiveUser ? ACTIVE_USER_BUBBLE_BACKGROUND : FRIEND_BUBBLE_BACKGROUND,
          alignment: isMessageFromActiveUser ? Alignment.topRight : Alignment.topLeft,
          tip: isFirstInThread,
          radius: 16.0
        ),
        child: Container(
          constraints: BoxConstraints.loose(MediaQuery.of(context).size * 0.8),
          padding: EdgeInsets.fromLTRB(
              isMessageFromActiveUser ? 8.0 : 18.0,
              8.0,
              isMessageFromActiveUser ? 18.0 : 8.0,
              8.0),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chatMessage.senderName,
                  style: TextStyle(
                      color: isMessageFromActiveUser
                          ? ACTIVE_USER_USERNAME_COLOR
                          : _getUserNameColor()
                  )
                ),
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
        )
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

class BubblePainter extends CustomPainter {
  final Color color;
  final Alignment alignment;
  final double radius;
  final bool tip;

  BubblePainter({
    @required this.color,
    @required this.alignment,
    @required this.radius,
    this.tip = false
  });

  double _x = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (alignment == Alignment.topRight) {
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          0,
          0,
          size.width - _x,
          size.height,
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(radius),
          topLeft: Radius.circular(radius),
          topRight: tip ? Radius.zero : Radius.circular(radius)
        ),
        Paint()
          ..color = this.color
          ..style = PaintingStyle.fill);
      if (tip) {
        var path = new Path();
        path.moveTo(size.width - _x, 0);
        path.lineTo(size.width - _x, 10);
        path.lineTo(size.width, 0);
        canvas.clipPath(path);
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(
            size.width - _x,
            0.0,
            size.width,
            size.height,
            topRight: Radius.circular(6),
          ),
          Paint()
            ..color = this.color
            ..style = PaintingStyle.fill);
      }
    } else {
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          _x,
          0,
          size.width,
          size.height,
          bottomRight: Radius.circular(radius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(radius),
          topLeft: tip ? Radius.zero : Radius.circular(radius)
        ),
        Paint()
          ..color = this.color
          ..style = PaintingStyle.fill);
      if (tip) {
        var path = new Path();
        path.moveTo(_x, 0);
        path.lineTo(_x, 10);
        path.lineTo(0, 0);
        canvas.clipPath(path);
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(
            0,
            0.0,
            _x,
            size.height,
            topLeft: Radius.circular(6),
          ),
          Paint()
            ..color = this.color
            ..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}