import 'package:flutter/services.dart';

/// Maps a raw key event to a table row navigation result. It returns null
/// when the event should be ignored, the new selected index otherwise, or
/// minus one when the Escape key clears the selection.
int? tableKeySelection(KeyEvent event, int currentIndex, int rowCount) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;

  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
    return currentIndex < rowCount - 1 ? currentIndex + 1 : 0;
  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
    return currentIndex > 0 ? currentIndex - 1 : rowCount - 1;
  } else if (event.logicalKey == LogicalKeyboardKey.escape) {
    return -1;
  }
  return null;
}
