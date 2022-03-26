import 'dart:ui' as ui;
import 'package:flutter/material.dart';

ui.TextDirection getAmbientDirection(BuildContext context, [defaultAmbientDirection = ui.TextDirection.ltr]) {
  ui.TextDirection ambientTextDirection = Directionality.of(context);
  if (ambientTextDirection == null) {
    ambientTextDirection = defaultAmbientDirection;
  }
  return ambientTextDirection;
}
