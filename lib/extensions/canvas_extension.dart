import 'dart:math' as math;

import 'package:flutter/material.dart';

extension CanvasEx on Canvas {
  /// Draws [shadow] for a given [path].
  ///
  /// Note that shadow's spreadRadius is not supported.
  void drawPathShadow(Path path, BoxShadow shadow) {
    this
      ..save()
      ..translate(shadow.offset.dx, shadow.offset.dy)
      ..drawPath(path, shadow.toPaint())
      ..restore();
  }

  /// Draws circular [shadow] for a given [circleRect].
  void drawCircleShadow(Rect circleRect, BoxShadow shadow) {
    final shadowBounds =
        circleRect.shift(shadow.offset).inflate(shadow.spreadRadius);

    drawCircle(
      shadowBounds.center,
      shadowBounds.width / 2,
      shadow.toPaint(),
    );
  }

  /// Draws circular inset [shadow] for a given [circleRect].
  /// 
  /// Inset shadow drawing logic is copied from flutter_inset_box_shadow 
  /// package.
  /// https://github.com/johynpapin/flutter_inset_box_shadow/blob/main/lib/src/box_decoration.dart
  void drawCircleInsetShadow(Rect circleRect, BoxShadow shadow) {
    final borderRadiusGeometry = BorderRadius.circular(circleRect.width);
    final borderRadius = borderRadiusGeometry.resolve(TextDirection.ltr);

    final clipRRect = borderRadius.toRRect(circleRect);

    final innerRect = circleRect.deflate(shadow.spreadRadius);
    final innerRRect = borderRadius.toRRect(innerRect);
    final outerRect = _areaCastingShadowInHole(circleRect, shadow);

    this
      ..save()
      ..clipRRect(clipRRect)
      ..drawDRRect(
        RRect.fromRectAndRadius(outerRect, Radius.zero),
        innerRRect.shift(shadow.offset),
        Paint()
          ..color = shadow.color
          ..colorFilter = ColorFilter.mode(shadow.color, BlendMode.src)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
      )
      ..restore();
  }

  Rect _areaCastingShadowInHole(Rect holeRect, BoxShadow shadow) {
    var bounds = holeRect;
    bounds = bounds.inflate(shadow.blurRadius);

    if (shadow.spreadRadius < 0) {
      bounds = bounds.inflate(-shadow.spreadRadius);
    }

    final offsetBounds = bounds.shift(shadow.offset);

    return _unionRects(bounds, offsetBounds);
  }

  Rect _unionRects(Rect a, Rect b) {
    if (a.isEmpty) {
      return b;
    }

    if (b.isEmpty) {
      return a;
    }

    final left = math.min(a.left, b.left);
    final top = math.min(a.top, b.top);
    final right = math.max(a.right, b.right);
    final bottom = math.max(a.bottom, b.bottom);

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
