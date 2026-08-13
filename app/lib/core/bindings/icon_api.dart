import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'syspie_library.dart';

/// Thin, typed wrapper over the native icon functions. It marshals FFI types
/// internally and returns plain Dart values only.
class IconApi {
  IconApi(this._lib);

  final SysPieLibrary _lib;

  /// Returns the icon for the given process as a base64 data URI.
  String getIcon(int pid) {
    final ptr = _lib.plGetIcon(pid);
    try {
      return ptr.toDartString();
    } finally {
      _lib.freeString(ptr);
    }
  }

  /// Returns icons for a batch of PIDs as a JSON string.
  String getIconsBatchJson(List<int> pids) {
    final count = pids.length;
    if (count == 0) return '{"icons":[]}';

    final array = calloc<Uint32>(count);
    try {
      for (var i = 0; i < count; i++) {
        array[i] = pids[i];
      }
      final ptr = _lib.plGetIconsBatchJson(array, count);
      try {
        return ptr.toDartString();
      } finally {
        _lib.freeString(ptr);
      }
    } finally {
      calloc.free(array);
    }
  }

  /// Returns the icon for the given AUMID as a base64 data URI.
  String getAumidIcon(String aumid) {
    final aumidPtr = aumid.toNativeUtf8();
    try {
      final ptr = _lib.plGetAumidIcon(aumidPtr);
      try {
        return ptr.toDartString();
      } finally {
        _lib.freeString(ptr);
      }
    } finally {
      calloc.free(aumidPtr);
    }
  }
}
