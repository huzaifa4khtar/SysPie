import 'package:ffi/ffi.dart';

import 'syspie_library.dart';

/// Thin, typed wrapper over the native shell functions. It marshals FFI types
/// internally and returns plain Dart values only.
class ShellApi {
  ShellApi(this._lib);

  final SysPieLibrary _lib;

  /// Opens the Windows Services app.
  bool openServices() => _lib.plOpenServices() == 1;

  /// Opens the Windows Properties dialog for the given process.
  bool openProperties(int pid) => _lib.plOpenProperties(pid) == 1;

  /// Opens Windows Explorer with the executable of the given process selected.
  bool openFileLocation(int pid) => _lib.plOpenFileLocation(pid) == 1;

  /// Opens a Windows system app and makes its window topmost over SysPie.
  void openWindowTopmost(String appName) {
    final nativeName = appName.toNativeUtf16();
    try {
      _lib.plOpenWindowTopmost(nativeName);
    } finally {
      calloc.free(nativeName);
    }
  }
}
