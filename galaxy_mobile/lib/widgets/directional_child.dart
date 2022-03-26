import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:galaxy_mobile/utils/ambient_direction.dart';

class DirectionalChild extends StatelessWidget {
  DirectionalChild({
    this.ltrChildBuilder,
    this.rtlChildBuilder,
    this.defaultAmbientDirection = ui.TextDirection.ltr
  });

  final ui.TextDirection defaultAmbientDirection;
  final Widget Function(BuildContext) ltrChildBuilder;
  final Widget Function(BuildContext) rtlChildBuilder;

  @override
  Widget build(BuildContext context) {
    ui.TextDirection ambientTextDirection =
      getAmbientDirection(context, defaultAmbientDirection);

    return ambientTextDirection == ui.TextDirection.ltr
        ? ltrChildBuilder(context)
        : rtlChildBuilder(context);
  }
}
