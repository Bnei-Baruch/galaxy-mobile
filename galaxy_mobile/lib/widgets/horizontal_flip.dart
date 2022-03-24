import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:galaxy_mobile/utils/ambient_direction.dart';

class HorizontalFlip extends StatelessWidget {
  HorizontalFlip({
    this.flipDirection,
    this.child,
    this.defaultAmbientDirection = ui.TextDirection.ltr
  });

  final ui.TextDirection defaultAmbientDirection;
  final ui.TextDirection flipDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    ui.TextDirection ambientTextDirection =
      getAmbientDirection(context, defaultAmbientDirection);
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
