import 'package:flutter/rendering.dart';

extension BoxShadowEx on BoxShadow {
  /// Creates scaled copy of this shadow according to the provided sizes. 
  BoxShadow resize({
    required double from,
    required double to,
  }) {
    if (from == to) {
      return this;
    }

    final factor = to / from;

    return BoxShadow(
      color: color,
      blurStyle: blurStyle,
      blurRadius: blurRadius * factor,
      spreadRadius: spreadRadius * factor,
      offset: offset.scale(factor, factor),
    );
  }
}
