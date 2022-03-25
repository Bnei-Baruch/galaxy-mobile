import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/question.dart';
import 'package:galaxy_mobile/utils/utils.dart';
import 'package:intl/intl.dart' as intl;
import 'package:mdi/mdi.dart';

class QuestionsList extends StatelessWidget {

  final List<Question> questions;

  QuestionsList({Key key, this.questions = const []}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
          children: questions
              .map((question) => QuestionCard(question))
              .toList()
          );
  }
}

class QuestionCard extends StatelessWidget {
  final Question question;
  QuestionCard(this.question);

  Widget build(BuildContext context) {
    bool isContentRTL = intl.Bidi.detectRtlDirectionality(question.content);
    ui.TextDirection textDirection = isContentRTL
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
    ui.TextAlign textAlign = isContentRTL
        ? ui.TextAlign.right
        : ui.TextAlign.left;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(5.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            textDirection: textDirection,
            children: <Widget>[
              Icon(Mdi.commentQuestion),
              SizedBox(width: 5),
              Expanded(
                child: RichText(
                  textDirection: textDirection,
                  textAlign: textAlign,
                  text: TextSpan(
                    text: Utils.formatTimestampAsDate(question.timestamp, 'HH:mm:ss'),
                    style: TextStyle(color: Colors.grey),
                    children: <TextSpan>[
                      const TextSpan(text: ' - '),
                      TextSpan(text: question.roomName),
                      const TextSpan(text: ' - '),
                      TextSpan(
                        text: question.userName,
                        style: TextStyle(
                          color: question.askForMe
                              ? Colors.green
                              : Colors.white)
                      ),
                      const TextSpan(text: ':')
                    ],
                  ),
                )
              )
            ]
          ),
          SizedBox(height: 5),
          Row(children: <Widget>[
            Expanded(
              child: Text(question.content,
                textDirection: textDirection,
                textAlign: textAlign))
          ])
          ]
        )
      )
    );
  }
}
