import 'package:ffi/ffi.dart';

import 'syspie_library.dart';

/// Thin, typed wrapper over the native user functions. It marshals FFI types
/// internally and returns plain Dart values only.
class UserApi {
  UserApi(this._lib);

  final SysPieLibrary _lib;

  /// Returns the users list as a JSON string.
  String listUsersJson() {
    final ptr = _lib.plListUsersJson();
    try {
      return ptr.toDartString();
    } finally {
      _lib.freeString(ptr);
    }
  }
}
