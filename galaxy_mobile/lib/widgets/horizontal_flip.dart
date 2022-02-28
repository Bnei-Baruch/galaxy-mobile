import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class HorizontalFlip extends StatelessWidget {
  HorizontalFlip({
    this.flipDirection,
    this.child,
    this.defaultAmbientDirection = ui.TextDirection.ltr
  });

  final ui.TextDirection defaultAmbientDirection;
  final ui.TextDirection flipDirection;
  final Widget child;

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
    bool shouldFlip = ambientTextDirection == flipDirection;

    return shouldFlip
      ? Transform(
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: child,
        alignment: Alignment.center,
      )
      : child;
  }
}
