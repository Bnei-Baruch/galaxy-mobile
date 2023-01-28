import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;

import 'package:galaxy_mobile/utils/utils.dart';

typedef OnSubmitMessageCallback = Function(String);

class SendChatMessageBar extends StatefulWidget {
  final OnSubmitMessageCallback onMessageSent;
  final bool enabled;

  SendChatMessageBar({this.enabled, this.onMessageSent});

  @override
  _SendChatMessageBarState createState() => _SendChatMessageBarState();
}

class _SendChatMessageBarState extends State<SendChatMessageBar> {
  final _textController = TextEditingController();
  bool isSendButtonEnabled = false;

  void _onSubmit() {
    if (_textController.text.isEmpty) {
      return;
    }

    final text = _textController.text;
    _textController.clear();

    widget.onMessageSent(text);
  }

  _updateSendButtonState() {
    setState(() {
      isSendButtonEnabled = widget.enabled && _textController.text.isNotEmpty;
    });
  }

  @override
  void didUpdateWidget(SendChatMessageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    this.setState(() {
      isSendButtonEnabled = isSendButtonEnabled && widget.enabled;
    });
  }

  @override
  void initState() {
    super.initState();
    _updateSendButtonState();
    _textController.addListener(_updateSendButtonState);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      child: Row(
        textDirection: ui.TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:  Color(0xFF232C32),
                borderRadius: BorderRadius.circular(20.0)
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 12.0,
                  ),
                  Expanded(
                    child: Container(
                      child: new ConstrainedBox(
                        constraints: BoxConstraints(
                        maxHeight: 140.0),
                        child: TextField(
                          style: TextStyle(
                              fontSize: 15.0,
                          ),
                          maxLines: null,
                          minLines: 1,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'virtual_chat.enterMessage'.tr(),
                            border: InputBorder.none,
                          ),
                          textDirection: Utils.isRTL(_textController.text) ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          controller: _textController,
                        )
                      ),
                    )
                  ),
                  SizedBox(
                    width: 12.0,
                  ),
                ]
              )
            )
          ),
          SizedBox(
            width: 12.0,
          ),
          GestureDetector(
            onTap: (isSendButtonEnabled) ? _onSubmit : null,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: isSendButtonEnabled ? Color(0xFF0062B0) : Colors.grey,
              foregroundColor: Colors.white,
              child: Icon(Icons.send_sharp),
            ),
          ),
        ]
      ),
    );
  }
}

