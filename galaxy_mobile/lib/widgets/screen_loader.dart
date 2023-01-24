import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';


class ScreenLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
        type: MaterialType.transparency,
        child:
      Container(
        color: Colors.black,
        child: FractionallySizedBox(
        widthFactor: 0.5,
        heightFactor: 0.5,
        child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset('assets/graphics/logo.png', fit: BoxFit.contain),
            LinearProgressIndicator(),
            FittedBox(
                  fit: BoxFit.fill,
                  child: Text('please wait'.tr(),style: TextStyle(
                    color: Colors.white,
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.end,
                  maxLines:  1,
                  )
              ),
          ],
        )))));
  }
}
