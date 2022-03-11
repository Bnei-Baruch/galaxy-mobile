
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/main_store.dart';
import 'package:galaxy_mobile/models/question.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/widgets/questions/questions_list.dart';
import 'package:galaxy_mobile/widgets/questions/send_question_form.dart';
import 'package:provider/provider.dart';

class QuestionsDialogContent extends StatefulWidget {
  @override
  _QuestionsDialogContentState createState() => _QuestionsDialogContentState();
}

class _QuestionsDialogContentState extends State<QuestionsDialogContent> {

  List<Question> questions = [];
  bool _isLoading = false;

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });
    List<Question> fetchedQuestions = [];
    String userId = context.read<MainStore>().activeUser.id;
    try {
      fetchedQuestions = await context.read<Api>().getQuestions(userId);
    } catch (e) {
      FlutterLogs.logInfo("QuestionsDialogContent", "loadQuestions", "Failed to load questions: " + e.toString());
    }
    setState(() {
      _isLoading = false;
      questions = fetchedQuestions;
    });
  }

  Future<void> _sendQuestion(String userName, String roomName, String questionContent) async {
    String gender = roomName.startsWith(RegExp(r'^W\s')) ? "female" : "male";
    return context.read<Api>().sendQuestion(
        context.read<MainStore>().activeUser.id, userName, roomName, questionContent, gender);
  }

  Future<void> _questionFormSubmissionCallback(String userName, String roomName, String questionContent) async {
    await _sendQuestion(userName, roomName, questionContent);
    // Load questions after question was sent.
    // Don't await for loading questions.
    _loadQuestions();
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: MediaQuery.of(context).orientation == Orientation.landscape
          ? Axis.horizontal  // as Row
          : Axis.vertical, // as Column
      children: [
        Expanded(child: Container(
            padding: EdgeInsets.only(left: 15.0, right: 15.0),
            child: SendQuestionForm(onSubmit: _questionFormSubmissionCallback))),
        _isLoading
            ? Expanded(child: Center(
                child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator())
            ))
            : Expanded(child: QuestionsList(questions: questions))
      ]
    );
  }
}