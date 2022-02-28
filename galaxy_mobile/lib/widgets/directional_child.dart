import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class DirectionalChild extends StatelessWidget {
  DirectionalChild({
    this.ltrChildBuilder,
    this.rtlChildBuilder,
    this.defaultAmbientDirection = ui.TextDirection.ltr
  });

  final ui.TextDirection defaultAmbientDirection;
  final Widget Function(BuildContext) ltrChildBuilder;
  final Widget Function(BuildContext) rtlChildBuilder;

  ui.TextDirection _getAmbientDirection(BuildContext context) {
    ui.TextDirection ambientTextDirection = Directionality.of(context);
    if (ambientTextDirection == null) {
      ambientTextDirection = defaultAmbientDirection;
    }
    return ambientTextDirection;
  }

  @override
  Widget build(BuildContext context) {
    ui.TextDirection ambientTextDirection = _getAmbientDirection(context);

    return ambientTextDirection == ui.TextDirection.ltr
        ? ltrChildBuilder(context)
        : rtlChildBuilder(context);
  }
}
