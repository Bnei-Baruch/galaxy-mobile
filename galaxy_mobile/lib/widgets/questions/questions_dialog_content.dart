
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/models/main_store.dart';
import 'package:galaxy_mobile/models/question.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/widgets/loader.dart';
import 'package:galaxy_mobile/widgets/questions/questions_list.dart';
import 'package:galaxy_mobile/widgets/questions/send_question_form.dart';
import 'package:provider/provider.dart';

class QuestionsDialogContent extends StatefulWidget {
  @override
  _QuestionsDialogContentState createState() => _QuestionsDialogContentState();
}

class _QuestionsDialogContentState extends State<QuestionsDialogContent> {

  LoaderController _loaderController;

  Future<List<Question>> _loadQuestions() async {
    List<Question> fetchedQuestions = [];
    String userId = context.read<MainStore>().activeUser.id;
    try {
      fetchedQuestions = await context.read<Api>().getQuestions(userId);
    } catch (e) {
      FlutterLogs.logInfo("QuestionsDialogContent", "loadQuestions", "Failed to load questions: " + e.toString());
    }
    return fetchedQuestions;
  }

  Future<void> _sendQuestion(String userName, String roomName, String questionContent) async {
    String gender = roomName.startsWith(RegExp(r'^W\s')) ? "female" : "male";
    return context.read<Api>().sendQuestion(
        context.read<MainStore>().activeUser.id, userName, roomName, questionContent, gender);
  }

  Future<void> _questionFormSubmissionCallback(String userName, String roomName, String questionContent) async {
    await _sendQuestion(userName, roomName, questionContent);
    // Reload questions after question was sent.
    _loaderController.reload();
  }

  @override
  void initState() {
    super.initState();
    _loaderController = LoaderController();
  }

  @override
  void dispose() {
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: MediaQuery.of(context).orientation == Orientation.landscape
          ? Axis.horizontal  // as Row
          : Axis.vertical, // as Column
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.only(left: 15.0, right: 15.0),
            child: SendQuestionForm(
              onSubmit: _questionFormSubmissionCallback
            )
          )
        ),
        Expanded(
          child: Loader<List<Question>>(
            resultBuilder: (BuildContext context, dynamic questions) {
              return QuestionsList(questions: questions);
            },
            controller: _loaderController,
            loadOnInit: true,
            load: () => _loadQuestions()
          )
        )
      ]
    );
  }
}
