import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'syspie_library.dart';

/// Thin, typed wrapper over the native process functions. It marshals FFI types
/// internally and returns plain Dart values only.
class ProcessApi {
  ProcessApi(this._lib);

  final SysPieLibrary _lib;

  /// Returns the process diff as a JSON string.
  String enumerateProcessesDiffJson() {
    final ptr = _lib.plEnumerateProcessesDiffJson();
    try {
      return ptr.toDartString();
    } finally {
      _lib.freeString(ptr);
    }
  }

  /// Terminates the given process by its PID.
  bool terminate(int pid) => _lib.plTerminate(pid) == 1;

  /// Terminates the process tree rooted at the given PID.
  bool terminateTree(int pid) => _lib.plTerminateTree(pid) == 1;

  /// Terminates a batch of processes and returns how many were terminated.
  int terminateBatch(List<int> pids) {
    final count = pids.length;
    if (count == 0) return 0;

    final array = calloc<Uint32>(count);
    try {
      for (var i = 0; i < count; i++) {
        array[i] = pids[i];
      }
      return _lib.plTerminateBatch(array, count);
    } finally {
      calloc.free(array);
    }
  }

  /// Closes the window identified by the given hwnd.
  bool closeWindow(int hwnd) => _lib.plCloseWindow(hwnd) == 1;

  /// Returns whether the given process is considered dangerous.
  bool checkDangerous(int pid) => _lib.plCheckDangerous(pid) == 1;
}
