// Loads the NT system information, process information, open process, and terminate process functions from ntdll.dll at runtime.

#include "common/nt_types.h"
#include <windows.h>

pfnNtQuerySystemInformation NtQuerySystemInformation = nullptr;
pfnNtQueryInformationProcess NtQueryInformationProcess = nullptr;
pfnNtOpenProcess NtOpenProcess = nullptr;
pfnNtTerminateProcess NtTerminateProcess = nullptr;

bool ntApiInit() {
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    if (!ntdll) {
        ntdll = LoadLibraryW(L"ntdll.dll");
    }
    if (!ntdll) return false;

    NtQuerySystemInformation = reinterpret_cast<pfnNtQuerySystemInformation>(
        GetProcAddress(ntdll, "NtQuerySystemInformation")
    );

    NtQueryInformationProcess = reinterpret_cast<pfnNtQueryInformationProcess>(
        GetProcAddress(ntdll, "NtQueryInformationProcess")
    );

    NtOpenProcess = reinterpret_cast<pfnNtOpenProcess>(
        GetProcAddress(ntdll, "NtOpenProcess")
    );

    NtTerminateProcess = reinterpret_cast<pfnNtTerminateProcess>(
        GetProcAddress(ntdll, "NtTerminateProcess")
    );

    return NtQuerySystemInformation != nullptr &&
           NtQueryInformationProcess != nullptr;
}
