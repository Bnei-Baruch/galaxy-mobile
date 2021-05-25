import 'package:flutter_logs/flutter_logs.dart';

class Logger {
  String tag = "";
  String defaultSubTag = "";
  Logger(this.tag, [String subTag = ""]) {
    this.defaultSubTag = subTag;
  }

  String getSubTag(String subTag) {
    return subTag ?? this.defaultSubTag;
  }

  void info(String logMessage, [String subTag]) async {
    return FlutterLogs.logInfo(this.tag, getSubTag(subTag), logMessage);
  }

  void warn(String logMessage, [String subTag]) async {
    return FlutterLogs.logWarn(this.tag, getSubTag(subTag), logMessage);
  }

  void error(String logMessage, [String subTag]) async {
    return FlutterLogs.logError(this.tag, getSubTag(subTag), logMessage);
  }

  void trace(String logMessage, Error e, [String subTag]) async {
    return FlutterLogs.logErrorTrace(this.tag, getSubTag(subTag), logMessage, e);
  }
}
