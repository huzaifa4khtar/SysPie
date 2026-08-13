import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Checks whether the current process is running with elevated (admin)
/// privileges by querying the access token.
bool isRunningElevated() {
  final phProcess = GetCurrentProcess();
  final phToken = calloc<Pointer>();

  try {
    if (!OpenProcessToken(phProcess, TOKEN_QUERY, phToken).value) return false;

    // TOKEN_ELEVATION is a single DWORD (4 bytes) holding a BOOL.
    final pElevation = calloc<Uint32>();
    final cbReturn = calloc<Uint32>();

    try {
      final result = GetTokenInformation(
        HANDLE(phToken.value),
        TOKEN_INFORMATION_CLASS(20), // TokenElevation
        pElevation.cast(),
        sizeOf<Uint32>(),
        cbReturn,
      );

      if (!result.value) return false;
      return pElevation.value != 0;
    } finally {
      calloc.free(pElevation);
      calloc.free(cbReturn);
    }
  } finally {
    CloseHandle(HANDLE(phToken.value));
    calloc.free(phToken);
  }
}

/// Relaunches the current process as admin via ShellExecuteEx with the
/// "runas" verb. Returns true if the elevation request was launched
/// successfully.
bool relaunchAsAdmin() {
  final exePath = Platform.resolvedExecutable.toNativeUtf16();
  final verb = 'runas'.toNativeUtf16();

  try {
    final info = calloc<SHELLEXECUTEINFO>()
      ..ref.cbSize = sizeOf<SHELLEXECUTEINFO>()
      ..ref.fMask = 0
      ..ref.hwnd = HWND(nullptr)
      ..ref.lpVerb = PWSTR(verb)
      ..ref.lpFile = PWSTR(exePath)
      ..ref.lpParameters = PWSTR(nullptr)
      ..ref.lpDirectory = PWSTR(nullptr)
      ..ref.nShow = SW_SHOWNORMAL;

    final result = ShellExecuteEx(info);
    calloc.free(info);
    if (!result.value) return false;

    // Give the elevated process a moment to start, then close this instance
    // so only the new admin window remains.
    Future.delayed(const Duration(milliseconds: 500), () => exit(0));
    return true;
  } finally {
    calloc.free(exePath);
    calloc.free(verb);
  }
}
