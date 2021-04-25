import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:easy_localization/easy_localization.dart';

class UILanguageSelector extends StatelessWidget {
  void setLanguage(BuildContext context, String language) {
    switch (language) {
      case "English":
        EasyLocalization.of(context).locale = Locale('en', 'US');
        break;

      case "Русский":
        EasyLocalization.of(context).locale = Locale('ru', 'RU');
        break;

      default:
        FlutterLogs.logError("UILanguageSelector", "setLanguage",
            "unsupported language: $language");
        break;
    }
  }

  String getLanguage(BuildContext context) {
    FlutterLogs.logInfo("UILanguageSelector", "getLanguage",
        ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ${EasyLocalization.of(context).locale.languageCode}");
    switch (EasyLocalization.of(context).locale.languageCode) {
      case "en":
        return "English";
        break;

      case "ru":
        return "Русский";
        break;

      default:
        FlutterLogs.logError("UILanguageSelector", "getLanguage",
            "unsupported language: "
                "${EasyLocalization.of(context).locale.languageCode}");
        return "";
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = ['English', 'Русский'];

    return DropdownSearch<String>(
      mode: Mode.DIALOG,
      label: "Interface Language",
      hint: "Select Language",
      items: languages,
      selectedItem: getLanguage(context),
      onChanged: (String language) => {
        FlutterLogs.logInfo("UILanguageSelector", "DropdownSearch.onChanged",
            "selected language: $language"),
        setLanguage(context, language)
      },
      showClearButton: false,
      showSearchBox: false
    );
  }
}
