#include "process/process_terminator.h"
#include "common/nt_types.h"

#include <windows.h>
#include <tlhelp32.h>
#include <vector>
#include <queue>
#include <unordered_map>
#include <unordered_set>
#include <string>

// Enables the debug privilege on the current process token, following the System Informer pattern.
static bool enableDebugPrivilege() {
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token)) {
        return false;
    }

    TOKEN_PRIVILEGES tp = {};
    tp.PrivilegeCount = 1;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;

    if (!LookupPrivilegeValueW(nullptr, L"SeDebugPrivilege", &tp.Privileges[0].Luid)) {
        CloseHandle(token);
        return false;
    }

    BOOL result = AdjustTokenPrivileges(token, FALSE, &tp, sizeof(tp), nullptr, nullptr);
    DWORD err = GetLastError();
    CloseHandle(token);

    return result && err == ERROR_SUCCESS;
}

// Hashes a lowercase process name with a simple 37 based multiplier, ported from System Informer.
static uint32_t hashProcessName(const wchar_t* name) {
    uint32_t hash = 0;
    while (*name) {
        hash = (hash * 37) + static_cast<uint32_t>(*name);
        name++;
    }
    return hash;
}

// Hashes of critical process names that must not be terminated, covering csrss, dwm, logonui, lsass, lsm, services, smss, wininit, and winlogon.
static const std::unordered_set<uint32_t> DangerousProcessHashes = {
    0x6ccbdb46,
    0x5920bffe,
    0x8880527b,
    0x9fd9b2be,
    0xb1c6af0a,
    0xaafce8c2,
    0xfe38787e,
    0x9d662730,
    0x2aa5caab,
};

// Looks up the lowercase executable name for a PID by walking the process snapshot.
static std::wstring getProcessExeName(uint32_t pid) {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return L"";

    PROCESSENTRY32W entry = {};
    entry.dwSize = sizeof(entry);

    std::wstring result;
    if (Process32FirstW(snapshot, &entry)) {
        do {
            if (entry.th32ProcessID == pid) {
                result = entry.szExeFile;
                for (auto& c : result) c = static_cast<wchar_t>(towlower(c));
                break;
            }
        } while (Process32NextW(snapshot, &entry));
    }
    CloseHandle(snapshot);
    return result;
}

// Checks if a PID belongs to a critical system process by hashing its executable name. PID 4 is always dangerous.
bool isDangerousProcess(uint32_t pid) {
    if (pid == 4) return true;

    std::wstring exeName = getProcessExeName(pid);
    if (exeName.empty()) return false;

    uint32_t hash = hashProcessName(exeName.c_str());
    return DangerousProcessHashes.count(hash) > 0;
}

// Returns the lowercase executable name of a dangerous process, or an empty string when it is safe.
std::wstring getDangerousProcessName(uint32_t pid) {
    if (pid == 4) return L"System (PID 4)";

    std::wstring exeName = getProcessExeName(pid);
    if (exeName.empty()) return L"";

    uint32_t hash = hashProcessName(exeName.c_str());
    if (DangerousProcessHashes.count(hash) > 0) {
        return exeName;
    }
    return L"";
}

// Terminates a process, enabling the debug privilege, opening it through the native call with a Win32 fallback, and terminating it the same way. A second pass uses the debug terminate exit code for robustness.
bool terminateProcess(uint32_t pid) {
    // Enable the debug privilege so any process can be opened.
    static bool debugPrivEnabled = enableDebugPrivilege();
    (void)debugPrivEnabled;

    // Open the process with terminate and query access.
    HANDLE handle = nullptr;
    OBJECT_ATTRIBUTES objAttr = {};
    objAttr.Length = sizeof(objAttr);

    CLIENT_ID clientId = {};
    clientId.UniqueProcess = reinterpret_cast<HANDLE>(static_cast<ULONG_PTR>(pid));
    clientId.UniqueThread = nullptr;

    NTSTATUS status = STATUS_ACCESS_DENIED;

    // Try the native open first because it can bypass some restrictions.
    if (NtOpenProcess) {
        status = NtOpenProcess(
            &handle,
            PROCESS_TERMINATE | PROCESS_QUERY_LIMITED_INFORMATION,
            &objAttr,
            &clientId
        );
    }

    // Fall back to the Win32 open call.
    if (!NT_SUCCESS(status) || !handle) {
        handle = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    }

    if (!handle || handle == INVALID_HANDLE_VALUE) {
        return false;
    }

    bool result = false;

    // Try the native terminate first, matching the System Informer pattern.
    if (NtTerminateProcess) {
        status = NtTerminateProcess(handle, 1); // The process exits with code 1.
        result = NT_SUCCESS(status);
    }

    // Fall back to the Win32 terminate call.
    if (!result) {
        result = TerminateProcess(handle, 1) != FALSE;
    }

    // Do a second pass with the debug terminate exit code for robustness.
    if (result) {
        if (NtTerminateProcess) {
            NtTerminateProcess(handle, static_cast<NTSTATUS>(0x40010001)); // DBG_TERMINATE_PROCESS
        } else {
            TerminateProcess(handle, 0x40010001);
        }
    }

    CloseHandle(handle);
    return result;
}

// Collects all descendant PIDs of a process using a breadth first walk over the parent to child map.
static void collectDescendants(uint32_t rootPid, std::vector<uint32_t>& descendants) {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return;

    PROCESSENTRY32W entry = {};
    entry.dwSize = sizeof(entry);

    std::unordered_map<uint32_t, std::vector<uint32_t>> parentMap;
    uint32_t processCount = 0;
    if (Process32FirstW(snapshot, &entry)) {
        do {
            parentMap[entry.th32ParentProcessID].push_back(entry.th32ProcessID);
            processCount++;
        } while (Process32NextW(snapshot, &entry));
    }
    CloseHandle(snapshot);

    descendants.reserve(processCount);

    std::queue<uint32_t> queue;
    queue.push(rootPid);
    while (!queue.empty()) {
        uint32_t current = queue.front();
        queue.pop();
        auto it = parentMap.find(current);
        if (it != parentMap.end()) {
            for (uint32_t child : it->second) {
                descendants.push_back(child);
                queue.push(child);
            }
        }
    }
}

// Terminates a process and all of its descendants, reporting whether any termination succeeded.
bool terminateProcessTree(uint32_t pid) {
    std::vector<uint32_t> pids;
    collectDescendants(pid, pids);
    pids.insert(pids.begin(), pid);

    bool anySuccess = false;
    for (uint32_t p : pids) {
        if (terminateProcess(p)) {
            anySuccess = true;
        }
    }
    return anySuccess;
}

// Terminates a list of processes and returns how many of them succeeded.
int terminateProcesses(const std::vector<uint32_t>& pids) {
    int successCount = 0;
    for (uint32_t pid : pids) {
        if (terminateProcess(pid)) {
            successCount++;
        }
    }
    return successCount;
}
