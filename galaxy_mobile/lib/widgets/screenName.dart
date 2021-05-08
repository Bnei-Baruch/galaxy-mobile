import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:easy_localization/easy_localization.dart';

typedef UserCallback = void Function(User user);

class ScreenName extends StatelessWidget {
  final name;
  ScreenName(this.name);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
        enabled: false,
        initialValue: name,
        decoration: InputDecoration(
          labelText: 'screen_name'.tr(),
          // errorText: 'Error message'v          ,
          border: OutlineInputBorder(),
        ));
  }
}
