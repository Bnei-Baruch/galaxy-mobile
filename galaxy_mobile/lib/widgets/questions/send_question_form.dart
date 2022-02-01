
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:galaxy_mobile/models/mainStore.dart';

typedef OnSubmitCallback = Future<void> Function(String userName, String roomName, String questionContent);

class SendQuestionForm extends StatefulWidget {
  final OnSubmitCallback onSubmit;
  SendQuestionForm({Key key, @required this.onSubmit}) : super(key: key);

  @override
  _SendQuestionFormState createState() => _SendQuestionFormState();
}

class _SendQuestionFormState extends State<SendQuestionForm> {
  final _formKey = GlobalKey<FormState>();

  String _userName;
  String _roomName;
  String _questionContent;
  // Marks that the form was submitted by the user
  // Note: does not mark whether the form submission was successful.
  bool _isSubmitted;
  // When the form is locked, non of the fields or button are active.
  bool _isFormLocked;

  // Resets the form, with an optional initial values for userName & roomName.
  void _resetForm({ String resetToUserName, String resetToRoomName }) {
    setState(() {
      _userName = resetToUserName ?? '';
      _roomName = resetToRoomName ?? context.read<MainStore>().activeRoom.description ?? '';
      _questionContent = '';
      _isSubmitted = false;
      _isFormLocked = false;
      if (_formKey.currentState != null) {
        _formKey.currentState.reset();
      }
    });
  }

  void _submit() async {
    setState(() {
      _isSubmitted = true;
    });
    if (_formKey.currentState.validate()) {
      // Lock the form until we get the answer from the callback.
      setState(() {
        _isFormLocked = true;
      });
      try {
        await widget.onSubmit(_userName, _roomName, _questionContent);
        // Reset the form, but keep the previous user name and room name.
        _resetForm(resetToUserName: _userName, resetToRoomName: _roomName);
        // TODO: should we show a snackbar with success?
        return;
      } catch (e) {
        FlutterLogs.logError("_SendQuestionFormState", "_submit", "onSubmit callback failed: " + e.toString());
        // TODO: should we show a snackbar with a failure?.
      }
    }
  }

  String _nonEmptyTextFieldValidator(String value) {
    if (value == null || value.isEmpty) {
      return 'Must not be empty';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  @override
  Widget build(BuildContext buildContext) {
    return ListView(children: [Form(
      key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextFormField(
              enabled: !_isFormLocked,
              initialValue: _userName,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: 'questions.userNameLabel'.tr(),
              ),
              validator: _nonEmptyTextFieldValidator,
              onChanged: (text) => setState(() => _userName = text),
              autovalidateMode: _isSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
            ),
            TextFormField(
              enabled: !_isFormLocked,
              initialValue: _roomName,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: 'questions.roomLabel'.tr(),
              ),
              validator: _nonEmptyTextFieldValidator,
              onChanged: (text) => setState(() => _roomName = text),
              autovalidateMode: _isSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
            ),
            TextFormField(
              enabled: !_isFormLocked,
              initialValue: "",
              maxLines: null,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: 'questions.enterQuestionLabel'.tr(),
              ),
              validator: _nonEmptyTextFieldValidator,
              autovalidateMode: _isSubmitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              onChanged: (text) => setState(() => _questionContent = text),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: ElevatedButton(
                style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.green)),
                onPressed: _isFormLocked ? null : _submit,
                child: Text('questions.sendQuestion'.tr()),
              ),
            ),
          ],
        ))]);
  }
}

