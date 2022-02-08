import 'package:flutter/material.dart';

class SendChatMessageBar extends StatefulWidget {
  //final ValueChanged<String> _onSubmit;

  //SendChatMessageBar(this._onSubmit);

  @override
  _SendChatMessageBarState createState() => _SendChatMessageBarState();
}

class _SendChatMessageBarState extends State<SendChatMessageBar> {
  final _textController = TextEditingController();
  bool isSendEnabled = false;

  void _onSubmit() {
    if (_textController.text.isEmpty) {
      return;
    }

    final text = _textController.text;
    _textController.clear();

    // TODO(yanive): remove print or use flutter log if we want to log submission.
    print("submitting: " + text);
    // widget._onSubmit
  }

  _updateSendState() {
    setState(() {
      isSendEnabled = _textController.text.isNotEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updateSendState);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:  Color(0xFF232C32),
                borderRadius: BorderRadius.circular(24.0)
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
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'Write to your ten...', // TODO: translate
                            border: InputBorder.none,
                          ),
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
            onTap: _onSubmit,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: isSendEnabled ? Color(0xFF0062B0) : Colors.grey,
              foregroundColor: Colors.white,
              child: Icon(Icons.send_sharp),
            ),
          ),
        ]
      ),
    );
  }
}

