
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mdi/mdi.dart';

class MainDialogHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBackPressed;

  MainDialogHeader({
    @required this.title,
    @required this.onBackPressed
  }) :  assert(onBackPressed != null),
        assert(title != null && title.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 4.0),
        height: 42,
        child: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.all(0)),
                child: Container(
                  height: 42,
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        left: -4,
                        top: -2,
                        child: Icon(Mdi.chevronLeft, color: Colors.white, size: 42)
                      ),
                      Positioned(
                        left: 30,
                        top: 12,
                        child: Text("dialog_back".tr().toUpperCase(),
                          style: TextStyle(color: Colors.white, fontSize: 12)
                        )
                      )
                    ]
                  )
                ),
                onPressed: () {
                  onBackPressed();
                },
              )
            ),
            Align(
              alignment: Alignment.center,
              child: Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
              )
            )
          ]
        )
    );
  }
}
