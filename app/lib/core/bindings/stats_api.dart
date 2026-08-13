import 'package:ffi/ffi.dart';

import 'syspie_library.dart';

/// Thin, typed wrapper over the native stats function. It marshals FFI types
/// internally and returns plain Dart values only.
class StatsApi {
  StatsApi(this._lib);

  final SysPieLibrary _lib;

  /// Returns the system stats as a JSON string.
  String statsJson() {
    final ptr = _lib.plGetStatsJson();
    try {
      return ptr.toDartString();
    } finally {
      _lib.freeString(ptr);
    }
  }
}
