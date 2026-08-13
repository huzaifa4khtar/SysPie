import 'package:flutter/material.dart';

/// A MaterialApp whose text is rendered at a 50 percent scale.
///
/// Flutter's test environment uses the Ahem font, where every glyph is as
/// wide as its font size, which is roughly twice as wide as real fonts like
/// Segoe UI or Roboto. Fixed width production layouts such as side menu
/// items, status badges, and table cells that fit fine at runtime overflow
/// in tests. Scaling the text only sets realistic proportional glyph widths.
///
/// This is applied through the MaterialApp builder so it overrides the
/// view derived MediaQuery. Wrapping MaterialApp externally does not work.
Widget scaledMaterialApp(Widget home) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(0.5)),
      child: child!,
    ),
    home: home,
  );
}
