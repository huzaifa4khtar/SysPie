import 'package:ffi/ffi.dart';

import 'syspie_library.dart';

/// Thin, typed wrapper over the native service functions. It marshals FFI types
/// internally and returns plain Dart values only.
class ServiceApi {
  ServiceApi(this._lib);

  final SysPieLibrary _lib;

  /// Returns the services enumeration as a JSON string.
  String enumerateServicesJson() {
    final ptr = _lib.plEnumerateServicesJson();
    try {
      return ptr.toDartString();
    } finally {
      _lib.freeString(ptr);
    }
  }

  /// Starts the service with the given name.
  bool start(String name) {
    final namePtr = name.toNativeUtf16();
    try {
      return _lib.plStartService(namePtr) == 1;
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Stops the service with the given name.
  bool stop(String name) {
    final namePtr = name.toNativeUtf16();
    try {
      return _lib.plStopService(namePtr) == 1;
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Restarts the service with the given name.
  bool restart(String name) {
    final namePtr = name.toNativeUtf16();
    try {
      return _lib.plRestartService(namePtr) == 1;
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Returns the last service error message, or null when it is empty.
  String? lastServiceError() {
    final ptr = _lib.plGetLastServiceError();
    try {
      final msg = ptr.toDartString();
      return msg.isEmpty ? null : msg;
    } finally {
      _lib.freeString(ptr);
    }
  }
}
