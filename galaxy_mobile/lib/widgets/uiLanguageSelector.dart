import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:easy_localization/easy_localization.dart';

class UILanguageSelector extends StatelessWidget {
  bool _withLabel;

  UILanguageSelector(bool withLabel) {
    _withLabel = withLabel;
  }

  void setLanguage(BuildContext context, String language) {
    switch (language) {
      case "English":
        EasyLocalization.of(context).locale = Locale('en', 'US');
        break;

      case "Русский":
        EasyLocalization.of(context).locale = Locale('ru', 'RU');
        break;

      case "עברית":
        EasyLocalization.of(context).locale = Locale('he', 'IL');
        break;

      case "Español":
        EasyLocalization.of(context).locale = Locale('es', '');
        break;

      default:
        FlutterLogs.logError("UILanguageSelector", "setLanguage",
            "unsupported language: $language");
        break;
    }
  }

  String getLanguage(BuildContext context) {
    switch (EasyLocalization.of(context).locale.languageCode) {
      case "en":
        return "English";
        break;

      case "ru":
        return "Русский";
        break;

      case "he":
        return "עברית";
        break;

      case "es":
        return "Español";
        break;

      default:
        FlutterLogs.logError(
            "UILanguageSelector",
            "getLanguage",
            "unsupported language: "
                "${EasyLocalization.of(context).locale.languageCode}");
        return "";
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = ['English', 'Русский', 'עברית', 'Español'];

    return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: DropdownSearch<String>(
            showSelectedItem: true,
            mode: Mode.DIALOG,
            label: _withLabel ? 'interface_language'.tr() : '',
            hint: 'select_language'.tr(),
            items: languages,
            selectedItem: getLanguage(context),
            onChanged: (String language) => {
                  FlutterLogs.logInfo(
                      "UILanguageSelector",
                      "DropdownSearch.onChanged",
                      "selected language: $language"),
                  setLanguage(context, language)
                },
            dropdownSearchDecoration: InputDecoration.collapsed(
                filled: true,
                //border: OutlineInputBorder(),
                // contentPadding: EdgeInsets.fromLTRB(12, 12, 8, 0),
                fillColor: Colors
                    .transparent //Theme.of(context).inputDecorationTheme.fillColor,
                ),
            showClearButton: false,
            showSearchBox: false));
  }
}
