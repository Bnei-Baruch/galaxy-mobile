import 'dart:ui' as ui;

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:intl/intl.dart' as intl;

// TODO: show "read more" for long messages.

const Color ACTIVE_USER_USERNAME_COLOR = Color(0xFF92B6D1);
const Color ACTIVE_USER_BUBBLE_BACKGROUND = Color(0xFF00488B);
const Color FRIEND_BUBBLE_BACKGROUND = Color(0xFF232C32);
const List<Color> USERNAME_COLORS = [
  Color(0xFFFFEBCD),
  Color(0xFFFFC75F),
  Color(0xFFFF9671),
  Color(0xFF8D7257),
  Color(0xFFFF6F91),
  Color(0xFF845EC2),
  Color(0xFFF3C5FF),
  Color(0xFFB0A8B9),
  Color(0xFF007C4C),
  Color(0xFF008F7A),
  Color(0xFF32B27E),
  Color(0xFFD3FBD8),
  Color(0xFFBBC6CE),
  Color(0xFF008E9B),
  Color(0xFF0089BA),
  Color(0xFF2C73D2),
  Color(0xFFD5CABD)
];

class ChatMessageBubble extends StatelessWidget {
  // Whether this bubble is the first in the thread.
  // A thread is a collection of messages from the same user.
  final bool isFirstInThread;
  final ChatMessage chatMessage;

  ChatMessageBubble({this.isFirstInThread = true, @required this.chatMessage});

  // Randomly generate a color from the hash of the username.
  Color _getUserNameColor(hash) {
    return USERNAME_COLORS[hash.abs() % USERNAME_COLORS.length];
  }

  Future<void> _onLinkOpen(LinkableElement link) async {
    if (await canLaunch(link.url)) {
      await launch(link.url);
    } else {
      FlutterLogs.logInfo("ChatMessageBubble", "_onLinkOpen", "Could not open link $link");
    }
  }

  Widget build(BuildContext context) {
    bool isMessageFromActiveUser = chatMessage.senderType == ChatMessageSender.ACTIVE_USER;

    bool isContentRTL = intl.Bidi.detectRtlDirectionality(chatMessage.messageContent);
    ui.TextDirection textDirection = isContentRTL
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;

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
              textDirection: ui.TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chatMessage.senderName,
                  style: TextStyle(
                      color: isMessageFromActiveUser
                          ? ACTIVE_USER_USERNAME_COLOR
                          : _getUserNameColor(chatMessage.senderName.hashCode)
                  )
                ),
                // TODO: Bidi is not supported very well: <hebrew><link><hebrew> doesn't render well.
                Directionality(
                  textDirection: textDirection,
                  child: Linkify(
                    options: LinkifyOptions(humanize: false),
                    onOpen: _onLinkOpen,
                    softWrap: true,
                    style: TextStyle(fontSize: 14),
                    text: chatMessage.messageContent,
                    textDirection: textDirection,
                 )
                ),
                Text(
                    Utils.formatTimestampAsDate(chatMessage.messageTime, "hh:mm"),
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)
                )
              ]),
        )
      );

    return Container(
      margin: EdgeInsets.only(top: isFirstInThread ? 10 : 2),
      child: Row(
        textDirection: ui.TextDirection.ltr,
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
            topRight: Radius.circular(5),
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
            topLeft: Radius.circular(5),
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