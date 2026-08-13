#include "process/process_enumerator.h"
#include "process/process_name_table.h"
#include "common/nt_types.h"

#include <windows.h>
#include <winsock2.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <iphlpapi.h>
#include <sddl.h>
#include <appmodel.h>
#include <shlwapi.h>
#include <wtsapi32.h>
#include <dwmapi.h>
#include <cstdio>
#include <cwchar>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <mutex>
#include <vector>
#include <string>

#include "network/network_etw.h"

// Version resources provide friendly names for processes.
#pragma comment(lib, "version.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "dwmapi.lib")

#pragma comment(lib, "iphlpapi.lib")

// Tracks deltas for rate calculations. initialized becomes true after the first sample so a newly spawned process does not report its full accumulated counters as a huge initial value.
struct ProcessDeltas {
    DeltaTracker kernelTime;
    DeltaTracker userTime;
    DeltaTracker diskReadBytes;
    DeltaTracker diskWriteBytes;
    bool initialized = false;
};

static std::unordered_map<ULONGLONG, ProcessDeltas> g_processDeltas;
static ULONGLONG g_prevTotalTime = 0;
static ULONGLONG g_prevTick = 0;
static bool g_firstRun = true;

// Serializes concurrent enumeration requests.
static std::mutex g_enumerateMutex;

// Caches PID to friendly name, refreshed on each enumeration pass.
static std::unordered_map<uint32_t, std::wstring> g_pidFriendlyNameCache;

// Tracks network byte deltas that come from the ETW provider.
static std::unordered_map<ULONGLONG, DeltaTracker> g_netDeltas;

// This is the hardcoded Windows Process list that Task Manager uses. Only these processes or critical ones show as Windows Processes, and everything else without a visible window is a background process. Source is Raymond Chen at Microsoft.

static const std::unordered_set<std::wstring> kKnownWindowsProcessNames = {
    L"system idle process", L"system", L"registry",
    L"smss.exe", L"csrss.exe", L"wininit.exe", L"winlogon.exe",
    L"services.exe", L"lsass.exe", L"svchost.exe",
    L"dwm.exe", L"conhost.exe", L"sihost.exe",
    L"werfault.exe", L"backgroundtaskhost.exe",
};

// Friendly names fall back to a shared known-name table when the PE description is missing or generic.
static const auto& kKnownProcessFriendlyNames = getKnownProcessNames();

// Opens a process handle, first at full query access and then at limited query access when that fails.
static HANDLE openProcess(HANDLE pid) {
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, (DWORD)(ULONG_PTR)pid);
    if (hProcess) return hProcess;
    hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)(ULONG_PTR)pid);
    return hProcess;
}

// Resolves a SID to its well known name. Matches the common service accounts, built in groups, font driver host, window manager, logon, and application package SIDs, returning an empty string when nothing matches.
static std::wstring getWellKnownSidName(PSID sid) {
    if (!sid) return L"";

    // Convert the SID to a string first, which is always safe.
    LPSTR sidString = NULL;
    if (!ConvertSidToStringSidA(sid, &sidString)) return L"";
    std::string str(sidString);
    LocalFree(sidString);

    if (str == "S-1-5-18") return L"SYSTEM";
    if (str == "S-1-5-19") return L"LOCAL SERVICE";
    if (str == "S-1-5-20") return L"NETWORK SERVICE";

    if (str == "S-1-5-32-544") return L"BUILTIN\\Administrators";
    if (str == "S-1-5-32-545") return L"BUILTIN\\Users";
    if (str == "S-1-5-32-546") return L"BUILTIN\\Guests";
    if (str == "S-1-5-32-547") return L"BUILTIN\\Power Users";
    if (str == "S-1-5-32-548") return L"BUILTIN\\Account Operators";
    if (str == "S-1-5-32-549") return L"BUILTIN\\Server Operators";
    if (str == "S-1-5-32-550") return L"BUILTIN\\Print Operators";

    if (str == "S-1-5-4")  return L"NT AUTHORITY\\INTERACTIVE";
    if (str == "S-1-5-6")  return L"NT AUTHORITY\\SERVICE";
    if (str == "S-1-5-7")  return L"NT AUTHORITY\\ANONYMOUS LOGON";
    if (str == "S-1-5-11") return L"NT AUTHORITY\\AUTHENTICATED USER";
    if (str == "S-1-5-13") return L"NT AUTHORITY\\TERMINAL SERVER USER";
    if (str == "S-1-5-14") return L"NT AUTHORITY\\REMOTE INTERACTIVE LOGON";

    // Font driver host SIDs drop the leading prefix and keep the id.
    if (str.compare(0, 10, "S-1-5-96-0-") == 0) {
        std::string id = str.substr(10);
        return L"Font Driver Host\\UMFD-" + std::wstring(id.begin(), id.end());
    }

    // Window manager SIDs keep the id after the prefix.
    if (str.compare(0, 10, "S-1-5-97-0-") == 0) {
        std::string id = str.substr(10);
        return L"Window Manager\\DWM-" + std::wstring(id.begin(), id.end());
    }

    // Service SIDs keep the id after the prefix.
    if (str.compare(0, 9, "S-1-5-94-") == 0) {
        std::string id = str.substr(9);
        return L"NT AUTHORITY\\SERVICE-" + std::wstring(id.begin(), id.end());
    }

    // Logon SIDs always resolve to the logon session account.
    if (str.compare(0, 9, "S-1-5-5-") == 0) {
        return L"NT AUTHORITY\\LogonSession";
    }

    if (str == "S-1-15-2-1") return L"ALL APPLICATION PACKAGES";

    return L"";
}

// Converts a SID to a username. Checks the well known SIDs first to skip the expensive account lookup, then falls back to the account lookup.
static std::wstring sidToUserName(PSID sid) {
    if (!sid) return L"-";

    std::wstring wellKnown = getWellKnownSidName(sid);
    if (!wellKnown.empty()) return wellKnown;

    SID_NAME_USE sidType;
    WCHAR name[256] = {0};
    WCHAR domain[256] = {0};
    DWORD nameLen = 256;
    DWORD domainLen = 256;
    if (LookupAccountSidW(NULL, sid, name, &nameLen, domain, &domainLen, &sidType)) {
        if (nameLen > 0) {
            return std::wstring(name);
        }
    }

    return L"-";
}

static std::wstring getProcessUserNameFromToken(HANDLE hProcess, DWORD pid = 0) {
    if (!hProcess) return L"-";
    HANDLE hToken = NULL;
    if (!OpenProcessToken(hProcess, TOKEN_QUERY, &hToken)) return L"-";

    DWORD tokenInfoLen = 0;
    GetTokenInformation(hToken, TokenUser, NULL, 0, &tokenInfoLen);
    std::vector<BYTE> buf(tokenInfoLen);
    if (!GetTokenInformation(hToken, TokenUser, buf.data(), tokenInfoLen, &tokenInfoLen)) {
        CloseHandle(hToken);
        return L"-";
    }

    PTOKEN_USER tokenUser = (PTOKEN_USER)buf.data();
    std::wstring result = sidToUserName(tokenUser->User.Sid);
    CloseHandle(hToken);
    return result;
}

// Reports whether every thread of the process is paused by checking the wait state and reason, counting suspended threads together with queued ones.
static bool isProcessSuspended(PSYSTEM_PROCESS_INFORMATION processInfo) {
    if (processInfo->NumberOfThreads == 0) return false;
    ULONG suspendedCount = 0;
    ULONG workqueueCount = 0;
    PBYTE threadBase = (PBYTE)processInfo + UFIELD_OFFSET(SYSTEM_PROCESS_INFORMATION, Threads);
    for (ULONG i = 0; i < processInfo->NumberOfThreads; i++) {
        PSYSTEM_EXTENDED_THREAD_INFORMATION extThread = (PSYSTEM_EXTENDED_THREAD_INFORMATION)(
            threadBase + sizeof(SYSTEM_EXTENDED_THREAD_INFORMATION) * i);
        if (extThread->ThreadInfo.ThreadState == THREAD_STATE_WAITING) {
            if (extThread->ThreadInfo.WaitReason == WRSuspended) {
                suspendedCount++;
            } else if (extThread->ThreadInfo.WaitReason == WRQueue) {
                workqueueCount++;
            }
        }
    }
    if (suspendedCount == 0) return false;
    return (suspendedCount + workqueueCount) == processInfo->NumberOfThreads;
}

// Builds a process ID to username map by enumerating terminal services processes, resolving each SID, and converting the SID to a string when the name lookup fails.
static std::unordered_map<DWORD, std::wstring> getWtsUserMap() {
    std::unordered_map<DWORD, std::wstring> map;
    PWTS_PROCESS_INFO_EXW pInfo = NULL;
    DWORD count = 0;
    DWORD level = 1;
    if (WTSEnumerateProcessesExW(WTS_CURRENT_SERVER_HANDLE, &level, WTS_ANY_SESSION,
        (LPWSTR*)&pInfo, &count)) {
        for (DWORD i = 0; i < count; i++) {
            if (pInfo[i].pUserSid && IsValidSid(pInfo[i].pUserSid)) {
                std::wstring name = sidToUserName(pInfo[i].pUserSid);
                if (name.empty() || name == L"-") {
                    // Fall back to the SID string form.
                    LPWSTR sidStr = NULL;
                    if (ConvertSidToStringSidW(pInfo[i].pUserSid, &sidStr)) {
                        name = sidStr;
                        LocalFree(sidStr);
                    }
                }
                if (!name.empty() && name != L"-") {
                    map[pInfo[i].ProcessId] = name;
                }
            }
        }
        WTSFreeMemoryExW(WTSTypeProcessInfoLevel1, pInfo, count);
    }
    return map;
}

// Detects whether a process owns a visible top level window.
struct WindowEnumData {
    DWORD processId;
    bool hasVisibleWindow;
};

// Window enumeration callback that marks a window as visible for a process.
static BOOL CALLBACK enumWindowsProc(HWND hwnd, LPARAM lParam) {
    auto* data = reinterpret_cast<WindowEnumData*>(lParam);
    DWORD windowPid = 0;
    GetWindowThreadProcessId(hwnd, &windowPid);
    if (windowPid == data->processId) {
        WCHAR className[256] = {};
        GetClassNameW(hwnd, className, 256);
        WCHAR winText[256] = {};
        GetWindowTextW(hwnd, winText, 256);

        if (IsWindowVisible(hwnd)) {
            LONG style = GetWindowLongW(hwnd, GWL_STYLE);
            LONG exStyle = GetWindowLongW(hwnd, GWL_EXSTYLE);

            if ((style & WS_VISIBLE) && (style & WS_CAPTION)) {
                if (exStyle & WS_EX_TOOLWINDOW) {
                    return TRUE;
                }
                HWND owner = GetWindow(hwnd, GW_OWNER);
                if (owner != NULL) {
                    return TRUE;
                }
                HWND parent = GetParent(hwnd);
                if (parent != NULL) {
                    return TRUE;
                }
                BOOL isCloaked = FALSE;
                if (SUCCEEDED(DwmGetWindowAttribute(
                        hwnd, DWMWA_CLOAKED, &isCloaked, sizeof(isCloaked)))) {
                    if (isCloaked) {
                        return TRUE;
                    }
                }
                data->hasVisibleWindow = true;
                return FALSE;
            }
        }
    }
    return TRUE;
}

// Builds a map of process IDs that own a visible top level window in a single pass.
static std::unordered_map<DWORD, bool> buildVisibleWindowMap() {
    std::unordered_map<DWORD, bool> pidHasWindow;
    struct EnumData {
        std::unordered_map<DWORD, bool>* map;
    };

    auto callback = [](HWND hwnd, LPARAM lParam) -> BOOL {
        auto* data = reinterpret_cast<EnumData*>(lParam);
        if (!IsWindowVisible(hwnd)) return TRUE;

        LONG style = GetWindowLongW(hwnd, GWL_STYLE);
        LONG exStyle = GetWindowLongW(hwnd, GWL_EXSTYLE);

        if (!(style & WS_CAPTION)) return TRUE;
        if (exStyle & WS_EX_TOOLWINDOW) return TRUE;

        HWND owner = GetWindow(hwnd, GW_OWNER);
        if (owner != NULL) return TRUE;

        HWND parent = GetParent(hwnd);
        if (parent != NULL) return TRUE;

        BOOL isCloaked = FALSE;
        if (SUCCEEDED(DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &isCloaked, sizeof(isCloaked)))) {
            if (isCloaked) return TRUE;
        }

        DWORD pid = 0;
        GetWindowThreadProcessId(hwnd, &pid);
        if (pid != 0) {
            (*data->map)[pid] = true;
        }
        return TRUE;
    };

    EnumData data = {&pidHasWindow};
    EnumWindows(callback, reinterpret_cast<LPARAM>(&data));
    return pidHasWindow;
}

// Returns true when the process owns a visible top level window, skipping the idle and system processes.
static bool detectVisibleWindow(DWORD processId, const std::wstring& processName,
                                 const std::unordered_map<DWORD, bool>& visibleWindowMap) {
    if (processId == 0 || processId == 4) return false;
    auto it = visibleWindowMap.find(processId);
    return it != visibleWindowMap.end() && it->second;
}

// Counts open TCP and UDP connections per process by scanning the extended owner PID tables.
static std::unordered_map<DWORD, uint32_t> buildConnectionCountMap() {
    std::unordered_map<DWORD, uint32_t> counts;
    DWORD tableSize = 0;

    GetExtendedTcpTable(NULL, &tableSize, FALSE, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0);
    if (tableSize > 0) {
        std::vector<BYTE> buf(tableSize);
        auto* table = reinterpret_cast<PMIB_TCPTABLE_OWNER_PID>(buf.data());
        if (GetExtendedTcpTable(table, &tableSize, FALSE, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0) == NO_ERROR) {
            for (DWORD i = 0; i < table->dwNumEntries; i++)
                counts[table->table[i].dwOwningPid]++;
        }
    }

    tableSize = 0;
    GetExtendedUdpTable(NULL, &tableSize, FALSE, AF_INET, UDP_TABLE_OWNER_PID, 0);
    if (tableSize > 0) {
        std::vector<BYTE> buf(tableSize);
        auto* table = reinterpret_cast<PMIB_UDPTABLE_OWNER_PID>(buf.data());
        if (GetExtendedUdpTable(table, &tableSize, FALSE, AF_INET, UDP_TABLE_OWNER_PID, 0) == NO_ERROR) {
            for (DWORD i = 0; i < table->dwNumEntries; i++)
                counts[table->table[i].dwOwningPid]++;
        }
    }
    return counts;
}

// Reads the process command line through the native query API using info class 60, which is available on Windows 10 and later.
static std::wstring getProcessCommandLine(HANDLE hProcess) {
    if (!hProcess) return L"";

    static pfnNtQueryInformationProcess pNtQIP = NULL;
    static bool tried = false;
    if (!tried) {
        tried = true;
        HMODULE hNtdll = GetModuleHandleW(L"ntdll.dll");
        if (hNtdll) {
            pNtQIP = (pfnNtQueryInformationProcess)GetProcAddress(hNtdll, "NtQueryInformationProcess");
        }
    }
    if (!pNtQIP) return L"";
    
    UNICODE_STRING cmdLine = {};
    NTSTATUS status = pNtQIP(hProcess, (PROCESSINFOCLASS)60, &cmdLine, sizeof(cmdLine), NULL);
    if (NT_SUCCESS(status) && cmdLine.Buffer && cmdLine.Length > 0) {
        return std::wstring(cmdLine.Buffer, cmdLine.Length / sizeof(WCHAR));
    }
    return L"";
}

// Maps a child process name substring to a matching parent process name substring.
struct IdeChildPattern {
    std::wstring childPattern;
    std::wstring parentPattern;
};

static const std::vector<IdeChildPattern> kIdeChildPatterns = {
    // Visual Studio children.
    {L"servicehub.", L"devenv.exe"},
    {L"servicehub.intellicode", L"devenv.exe"},
    {L"servicehub.identity", L"devenv.exe"},
    {L"servicehub.host", L"devenv.exe"},
    {L"servicehub.host.netfx.x64", L"devenv.exe"},
    {L"msbuild.exe", L"devenv.exe"},
    {L"vsdbg.exe", L"devenv.exe"},
    {L"vcpkgsrv.exe", L"devenv.exe"},
    {L"vcpkgsrv.exe", L"msbuild.exe"},          // Via MSBuild
    {L"copilot-language-server.exe", L"devenv.exe"},
    {L"copilot-language-server.exe", L"node.exe"}, // Via Node.js
    {L"vshost.exe", L"devenv.exe"},
    {L"vshost.exe", L"msbuild.exe"},
    {L"node.exe", L"devenv.exe"},
    
    // VS Code children.
    {L"bun", L"code.exe"},
    {L"bun.exe", L"code.exe"},
    {L"pty host", L"code.exe"},          // ConPTY terminal host
    {L"console window host", L"code.exe"}, // conhost under code

    // Debugger patterns apply to any parent.
    {L"vsdbg.exe", L""},
};

// Classifies a process to match Task Manager. A visible top level window makes it an app, a critical process or one in the hardcoded list makes it a Windows process, and everything else is a background process. Process IDs 0 and 4 are always Windows processes. Source is Raymond Chen at Microsoft.
static void classifyProcess(
    uint32_t pid, const std::wstring& name,
    bool hasVisibleWindow, bool isCritical,
    bool& isSystemProcess, bool& isBackground)
{
    if (pid == 0 || pid == 4) {
        isSystemProcess = true;
        isBackground = false;
        return;
    }

    if (hasVisibleWindow) {
        isSystemProcess = false;
        isBackground = false;
        return;
    }

    if (isCritical) {
        isSystemProcess = true;
        isBackground = false;
        return;
    }

    std::wstring lowerName = name;
    std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::towlower);
    if (kKnownWindowsProcessNames.count(lowerName) > 0) {
        isSystemProcess = true;
        isBackground = false;
        return;
    }

    isSystemProcess = false;
    isBackground = true;
}

// Reads friendly names from the Shell MUI cache registry key, keyed by the lowercase executable path.
static std::unordered_map<std::wstring, std::wstring> buildMuiCacheMap() {
    std::unordered_map<std::wstring, std::wstring> cache;
    HKEY hKey = NULL;
    if (RegOpenKeyExW(HKEY_CLASSES_ROOT,
        L"Local Settings\\Software\\Microsoft\\Windows\\Shell\\MuiCache",
        0, KEY_READ, &hKey) != ERROR_SUCCESS)
    {
        return cache;
    }

    DWORD index = 0;
    WCHAR valueName[1024];
    DWORD valueNameLen;
    BYTE valueData[1024];
    DWORD valueDataLen;
    DWORD valueType = 0;

    while (true) {
        valueNameLen = 1024;
        valueDataLen = 1024;
        if (RegEnumValueW(hKey, index, valueName, &valueNameLen,
            NULL, &valueType, valueData, &valueDataLen) != ERROR_SUCCESS)
        {
            break;
        }
        if (valueType == REG_SZ && valueDataLen > 0) {
            std::wstring vn(valueName, valueNameLen);
            std::wstring vd(reinterpret_cast<WCHAR*>(valueData),
                (valueDataLen / sizeof(WCHAR)) > 0 ?
                (valueDataLen / sizeof(WCHAR)) - 1 : 0);
            size_t dotPos = vn.find(L'.');
            if (dotPos != std::wstring::npos) {
                std::wstring regExePath = vn.substr(0, dotPos);
                std::transform(regExePath.begin(), regExePath.end(),
                    regExePath.begin(), ::towlower);
                if (!vd.empty()) {
                    cache[regExePath] = vd;
                }
            }
        }
        index++;
    }
    RegCloseKey(hKey);
    return cache;
}

// Enumerates all running processes and returns their structured metrics.
std::vector<ProcessInfo> enumerateProcesses() {
    std::lock_guard<std::mutex> lock(g_enumerateMutex);
    std::vector<ProcessInfo> result;

    // Query CPU information for delta calculations.
    SYSTEM_BASIC_INFORMATION basicInfo = {};
    NtQuerySystemInformation(SystemBasicInformation, &basicInfo, sizeof(basicInfo), NULL);
    ULONG numProcessors = basicInfo.NumberOfProcessors;
    if (numProcessors > 256) numProcessors = 256;

    SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION cpuInfo[256] = {};
    NtQuerySystemInformation(
        SystemProcessorPerformanceInformation, cpuInfo,
        sizeof(SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION) * numProcessors, NULL);

    ULONGLONG totalKernelTime = 0;
    ULONGLONG totalUserTime = 0;
    ULONGLONG totalIdleTime = 0;
    for (ULONG i = 0; i < numProcessors; i++) {
        totalKernelTime += cpuInfo[i].KernelTime.QuadPart - cpuInfo[i].IdleTime.QuadPart;
        totalUserTime += cpuInfo[i].UserTime.QuadPart;
        totalIdleTime += cpuInfo[i].IdleTime.QuadPart;
    }
    ULONGLONG totalTime = totalKernelTime + totalUserTime + totalIdleTime;
    ULONGLONG totalTimeDelta = totalTime - g_prevTotalTime;
    g_prevTotalTime = totalTime;

    ULONGLONG currentTick = GetTickCount64();
    ULONGLONG tickDelta = currentTick - g_prevTick;
    if (tickDelta == 0) tickDelta = 1;
    g_prevTick = currentTick;

    // Enumerate processes through the extended system call.
    PVOID processBuffer = NULL;
    ULONG bufferSize = 0x10000;
    NTSTATUS status;

    for (int retry = 0; retry < 20; retry++) {
        if (processBuffer) HeapFree(GetProcessHeap(), 0, processBuffer);
        processBuffer = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, bufferSize);
        if (!processBuffer) return result;

        status = NtQuerySystemInformation(
            SystemExtendedProcessInformation, processBuffer, bufferSize, &bufferSize);
        if (NT_SUCCESS(status)) break;
        if (status != STATUS_INFO_LENGTH_MISMATCH && status != STATUS_BUFFER_TOO_SMALL) {
            HeapFree(GetProcessHeap(), 0, processBuffer);
            return result;
        }
    }

    if (!NT_SUCCESS(status) || !processBuffer) {
        if (processBuffer) HeapFree(GetProcessHeap(), 0, processBuffer);
        return result;
    }

    // Snapshot the ETW network accumulations once for this pass.
    auto netSnapshot = g_networkMonitor.snapshot();

    // Build a WTS username map as a fallback when a process cannot be opened.
    auto wtsUserMap = getWtsUserMap();

    // Batch the connection counts to avoid per process table scans.
    auto connectionCounts = buildConnectionCountMap();

    // Do a single window enumeration pass for visible window detection.
    auto visibleWindowMap = buildVisibleWindowMap();

    // Read the MUI cache friendly names in one registry pass.
    auto muiCacheMap = buildMuiCacheMap();

    // Iterate over every process entry.
    PSYSTEM_PROCESS_INFORMATION spi = PH_FIRST_PROCESS(processBuffer);
    std::unordered_map<ULONGLONG, int> pidToIndex;

    while (spi) {
        HANDLE pid = spi->UniqueProcessId;
        ULONGLONG pidVal = (ULONGLONG)(ULONG_PTR)pid;
        ProcessInfo pi;
        pi.pid = (uint32_t)(ULONG_PTR)pid;
        pi.parentPid = (uint32_t)(ULONG_PTR)spi->InheritedFromUniqueProcessId;

        if (spi->ImageName.Length > 0 && spi->ImageName.Buffer) {
            pi.name.assign(spi->ImageName.Buffer, spi->ImageName.Length / sizeof(WCHAR));
        } else {
            pi.name = (ULONG_PTR)pid == 0 ? L"System Idle Process" : L"";
        }

        // detailName holds the technical exe name for the subtitle display.
        pi.detailName = pi.name;

        pi.basePriority = spi->BasePriority;
        pi.threadCount = spi->NumberOfThreads;
        pi.handleCount = spi->HandleCount;
        pi.sessionId = spi->SessionId;
        pi.createTime = spi->CreateTime.QuadPart;

        // Detect the process state from thread suspension.
        bool suspended = isProcessSuspended(spi);

        // The working set private size drives the memory value, matching the active private working set that excludes shared DLL pages.
        pi.workingSetMB = (double)spi->WorkingSetPrivateSize / (1024.0 * 1024.0);
        pi.memoryBytes = (double)spi->WorkingSetPrivateSize;
        pi.memoryMB = pi.workingSetMB;
        pi.virtualMemoryMB = (double)spi->VirtualSize / (1024.0 * 1024.0);

        // CPU usage is a delta based percentage.
        ULONGLONG procKernel = spi->KernelTime.QuadPart;
        ULONGLONG procUser = spi->UserTime.QuadPart;
        auto& deltas = g_processDeltas[pidVal];
        ULONGLONG kernelDelta = deltas.kernelTime.update(procKernel);
        ULONGLONG userDelta = deltas.userTime.update(procUser);

        if (deltas.initialized && !g_firstRun && totalTimeDelta > 0) {
            pi.cpuUsage = (double)(kernelDelta + userDelta) / (double)totalTimeDelta * 100.0;
        }

        // The extension pointer carries the disk counters and SID, which need extended process information.
        PSYSTEM_PROCESS_INFORMATION_EXTENSION ext = PH_PROCESS_EXTENSION(spi);
        PBYTE processEnd = spi->NextEntryOffset
            ? (PBYTE)spi + spi->NextEntryOffset
            : (PBYTE)processBuffer + bufferSize;
        PBYTE extEnd = (PBYTE)ext + sizeof(SYSTEM_PROCESS_INFORMATION_EXTENSION);
        bool extValid = (extEnd <= processEnd && ext->UserSidOffset > 0);
        bool diskExtValid = (extEnd <= processEnd);

        // Disk I/O uses the extension disk counters which track physical disk activity per process
        // and match what Task Manager shows. The base IO transfer counts track logical I/O instead,
        // so processes served from cache show reads there while system services writing to disk show
        // nothing. The extension validity for disk only requires the structure to be in bounds, since
        // the user SID offset can be zero for system processes without affecting the disk counters.
        {
            ULONGLONG diskRead = 0;
            ULONGLONG diskWrite = 0;

            if (diskExtValid) {
                diskRead = ext->DiskCounters.BytesRead;
                diskWrite = ext->DiskCounters.BytesWritten;
            } else {
                diskRead = spi->ReadTransferCount.QuadPart;
                diskWrite = spi->WriteTransferCount.QuadPart;
            }

            ULONGLONG readDelta = deltas.diskReadBytes.update(diskRead);
            ULONGLONG writeDelta = deltas.diskWriteBytes.update(diskWrite);

            if (deltas.initialized && !g_firstRun && tickDelta > 0) {
                pi.diskReadMB = (double)(readDelta) / (1024.0 * 1024.0) * 1000.0 / (double)tickDelta;
                pi.diskWriteMB = (double)(writeDelta) / (1024.0 * 1024.0) * 1000.0 / (double)tickDelta;
            }
        }

        // The idle and system processes always show the SYSTEM user.
        if ((ULONG_PTR)pid == 0 || (ULONG_PTR)pid == 4) {
            pi.userName = L"SYSTEM";
        }

        // Open a process handle for the token, UAC, critical, frozen, and wow64 checks.
        HANDLE hProcess = openProcess(pid);
        DWORD openProcErr = hProcess ? 0 : GetLastError();
        bool isCritical = false;

        if (hProcess) {
            // The token based username is the primary source and matches Task Manager.
            std::wstring tokenUser = getProcessUserNameFromToken(hProcess, (DWORD)(ULONG_PTR)pid);
            if (!tokenUser.empty() && tokenUser != L"-") {
                pi.userName = tokenUser;
            }

            PROCESS_EXTENDED_BASIC_INFORMATION extBasic = {};
            extBasic.Size = sizeof(PROCESS_EXTENDED_BASIC_INFORMATION);
            if (NT_SUCCESS(NtQueryInformationProcess(
                hProcess, ProcessBasicInformation, &extBasic, sizeof(extBasic), NULL)))
            {
                pi.isWow64 = extBasic.IsWow64Process;
                pi.isProtected = extBasic.IsProtectedProcess;
                if (extBasic.IsFrozen) {
                    suspended = true;
                }
            }

            // A process is critical when break on termination is set, which is how Task Manager identifies Windows processes.
            ULONG breakOnTermination = 0;
            ULONG retLen = 0;
            if (NT_SUCCESS(NtQueryInformationProcess(
                hProcess, ProcessBreakOnTermination,
                &breakOnTermination, sizeof(ULONG), &retLen)))
            {
                isCritical = (breakOnTermination != 0);
            }

            // UAC virtualization has the three states of enabled, disabled, or not allowed, read through token class 23 for allowed and class 24 for enabled.
            {
                HANDLE hToken = NULL;
                if (OpenProcessToken(hProcess, TOKEN_QUERY, &hToken)) {
                    DWORD virtAllowed = 0;
                    DWORD virtEnabled = 0;
                    DWORD tokenRetLen = 0;
                    if (GetTokenInformation(hToken, (TOKEN_INFORMATION_CLASS)23,
                        &virtAllowed, sizeof(virtAllowed), &tokenRetLen) && tokenRetLen == sizeof(DWORD)) {
                        if (virtAllowed == 0) {
                            pi.uacVirtualization = L"Not Allowed";
                        } else {
                            virtEnabled = 0;
                            tokenRetLen = 0;
                            if (GetTokenInformation(hToken, (TOKEN_INFORMATION_CLASS)24,
                                &virtEnabled, sizeof(virtEnabled), &tokenRetLen) && tokenRetLen == sizeof(DWORD)) {
                                pi.uacVirtualization = virtEnabled ? L"Enabled" : L"Disabled";
                            } else {
                                pi.uacVirtualization = L"Disabled";
                            }
                        }
                    }
                    CloseHandle(hToken);
                } else {
                    // Fall back to the native query with the process token class.
                    HANDLE hToken2 = NULL;
                    if (NT_SUCCESS(NtQueryInformationProcess(hProcess, (PROCESSINFOCLASS)ProcessToken,
                        &hToken2, sizeof(hToken2), NULL))) {
                        DWORD virtAllowed = 0;
                        DWORD virtEnabled = 0;
                        DWORD tokenRetLen = 0;
                        if (GetTokenInformation(hToken2, (TOKEN_INFORMATION_CLASS)23,
                            &virtAllowed, sizeof(virtAllowed), &tokenRetLen) && tokenRetLen == sizeof(DWORD)) {
                            if (virtAllowed == 0) {
                                pi.uacVirtualization = L"Not Allowed";
                            } else {
                                virtEnabled = 0;
                                tokenRetLen = 0;
                                if (GetTokenInformation(hToken2, (TOKEN_INFORMATION_CLASS)24,
                                    &virtEnabled, sizeof(virtEnabled), &tokenRetLen) && tokenRetLen == sizeof(DWORD)) {
                                    pi.uacVirtualization = virtEnabled ? L"Enabled" : L"Disabled";
                                } else {
                                    pi.uacVirtualization = L"Disabled";
                                }
                            }
                        }
                        CloseHandle(hToken2);
                    }
                }
            }

            CloseHandle(hProcess);
        }

        // Set the final status after the frozen check.
        pi.status = suspended ? L"SUSPENDED" : L"RUNNING";
        pi.statusType = suspended ? 2 : 0;
        pi.isSuspended = suspended;

        // The network I/O rate comes from the kernel network ETW provider.
        {
            auto netIt = netSnapshot.find((DWORD)(ULONG_PTR)pid);
            if (netIt != netSnapshot.end()) {
                ULONGLONG netBytes = netIt->second.totalBytes();
                auto& netDelta = g_netDeltas[pidVal];
                ULONGLONG netBytesDelta = netDelta.update(netBytes);

                if (deltas.initialized && !g_firstRun && tickDelta > 0) {
                    pi.networkBps = (double)netBytesDelta * 1000.0 / (double)tickDelta;
                }
            } else {
                auto ndIt = g_netDeltas.find(pidVal);
                if (ndIt != g_netDeltas.end()) {
                    g_netDeltas.erase(ndIt);
                }
            }
        }

        // When the process could not be opened, fall back to the SID from the system wide enumeration, using the offset relative to either the entry or its extension.
        if (pi.userName.empty() && extValid) {
            PSID sid1 = (PSID)((PBYTE)ext + ext->UserSidOffset);
            PSID sid2 = (PSID)((PBYTE)spi + ext->UserSidOffset);
            PSID sid = NULL;
            if (IsValidSid(sid1) && GetLengthSid(sid1) >= 8 && GetLengthSid(sid1) <= 68) {
                sid = sid1;
            } else if (IsValidSid(sid2) && GetLengthSid(sid2) >= 8 && GetLengthSid(sid2) <= 68) {
                sid = sid2;
            }
            if (sid) {
                DWORD sidLen = GetLengthSid(sid);
                if (sidLen > 0 && (PBYTE)sid + sidLen <= processEnd) {
                    pi.userName = sidToUserName(sid);
                }
            }
        }

        if (pi.userName.empty()) {
            auto it = wtsUserMap.find(pi.pid);
            if (it != wtsUserMap.end()) {
                pi.userName = it->second;
            } else if (!pi.name.empty()) {
                std::wstring pname = pi.name;
                std::transform(pname.begin(), pname.end(), pname.begin(), ::towlower);
                if (pname == L"fontdrvhost.exe") {
                    pi.userName = L"UMFD-" + std::to_wstring(pi.sessionId);
                } else if (pname == L"dwm.exe") {
                    pi.userName = L"DWM-" + std::to_wstring(pi.sessionId);
                } else {
                    pi.userName = L"SYSTEM";
                }
            } else {
                pi.userName = L"SYSTEM";
            }
        }

        // Set the visible window flag from the prebuilt map.
        pi.hasVisibleWindow = detectVisibleWindow((DWORD)(ULONG_PTR)pid, pi.name, visibleWindowMap);

        // Read the connection count for the process.
        pi.networkConnections = connectionCounts[(DWORD)(ULONG_PTR)pid];

        // Classify the process using the Task Manager algorithm.
        classifyProcess(
            pi.pid, pi.name,
            pi.hasVisibleWindow, isCritical,
            pi.isSystemProcess, pi.isBackground);

        pidToIndex[pidVal] = (int)result.size();
        result.push_back(std::move(pi));

        // Mark delta tracking initialized only after all metrics are computed, so the first sample of a new process does not report the accumulated counters as a delta.
        deltas.initialized = true;

        spi = PH_NEXT_PROCESS(spi);
    }

    // Build the parent child relationships from the recorded parent IDs.
    for (auto& proc : result) {
        if (proc.parentPid != 0) {
            auto it = pidToIndex.find(proc.parentPid);
            if (it != pidToIndex.end()) {
                result[it->second].hasChildren = true;
                result[it->second].childCount++;
            }
        }
        // Default UAC virtualization to not allowed when the process could not be read.
        if (proc.uacVirtualization.empty()) {
            proc.uacVirtualization = L"Not Allowed";
        }
    }

    // Mark known IDE child processes with hasIdeMatch by matching patterns so the app can nest them. This does not change the background or system flags set by classifyProcess.
    {
        for (auto& proc : result) {
            if (!proc.isBackground || proc.isSystemProcess) continue;
            
            std::wstring lowerName = proc.name;
            std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::towlower);
            
            if (proc.parentPid != 0) {
                auto parentIt = pidToIndex.find(proc.parentPid);
                if (parentIt != pidToIndex.end()) {
                    const auto& parent = result[parentIt->second];
                    std::wstring lowerParentName = parent.name;
                    std::transform(lowerParentName.begin(), lowerParentName.end(),
                                   lowerParentName.begin(), ::towlower);
                    
                    for (const auto& pattern : kIdeChildPatterns) {
                        if (lowerName.find(pattern.childPattern) != std::wstring::npos) {
                            if (pattern.parentPattern.empty() ||
                                lowerParentName.find(pattern.parentPattern) != std::wstring::npos) {
                                proc.hasIdeMatch = true;
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    // Remove PIDs that are no longer active from the delta tracking maps.
    {
        std::unordered_set<ULONGLONG> activePids;
        activePids.reserve(result.size());
        for (const auto& proc : result) {
            activePids.insert((ULONGLONG)(ULONG_PTR)proc.pid);
        }
        auto cleanupMap = [&](auto& map) {
            for (auto it = map.begin(); it != map.end(); ) {
                if (activePids.find(it->first) == activePids.end()) {
                    it = map.erase(it);
                } else {
                    ++it;
                }
            }
        };
        cleanupMap(g_processDeltas);
        cleanupMap(g_netDeltas);
    }

    // Resolve friendly names through several fallbacks, from packaged app names down to known process mappings and then the PE version resources, cached by full path and last write time.
    struct FriendlyNameCacheEntry {
        std::wstring friendlyName;
        FILETIME lastWriteTime;
    };
    static std::unordered_map<std::wstring, FriendlyNameCacheEntry> g_friendlyNameCache;

    for (auto& proc : result) {
        std::wstring lowerName = proc.name;
        std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::towlower);

        // The service host name is resolved later in enrichProcesses, so leave it unset here.

        // Resolve packaged app names by reading the display name from the AppModel repository, preferring the per app display name and falling back to the package level one.
        {
            HANDLE hPkgProc = openProcess((HANDLE)(ULONG_PTR)(ULONGLONG)proc.pid);
            if (hPkgProc) {
                UINT32 packageFullNameLength = 0;
                LONG rc = GetPackageFullName(hPkgProc, &packageFullNameLength, NULL);
                if (rc == ERROR_INSUFFICIENT_BUFFER && packageFullNameLength > 0) {
                    std::vector<WCHAR> packageFullName(packageFullNameLength);
                    rc = GetPackageFullName(hPkgProc, &packageFullNameLength, packageFullName.data());
                    if (rc == ERROR_SUCCESS) {
                        std::wstring pkgName(packageFullName.data());

                        // The AUMID and the app id are used for the per app display name lookup and for grouping.
                        std::wstring appId;
                        {
                            UINT32 aumidLength = 0;
                            LONG aumidRc = GetApplicationUserModelId(hPkgProc, &aumidLength, NULL);
                            if (aumidRc == ERROR_INSUFFICIENT_BUFFER && aumidLength > 0) {
                                std::vector<WCHAR> aumidBuf(aumidLength);
                                aumidRc = GetApplicationUserModelId(hPkgProc, &aumidLength, aumidBuf.data());
                                if (aumidRc == ERROR_SUCCESS) {
                                    proc.aumid.assign(aumidBuf.data());
                                    // Parse the app id from the AUMID, which places the package family name before an exclamation mark.
                                    size_t bangPos = proc.aumid.find(L'!');
                                    if (bangPos != std::wstring::npos) {
                                        appId = proc.aumid.substr(bangPos + 1);
                                    }
                                }
                            }
                        }

                        // Look up the display name from the AppModel repository.
                        HKEY hKey = NULL;
                        std::wstring regBase = L"Local Settings\\Software\\Microsoft\\Windows\\CurrentVersion\\AppModel\\Repository\\Packages\\";
                        std::wstring regPath = regBase + pkgName;
                        if (RegOpenKeyExW(HKEY_CLASSES_ROOT, regPath.c_str(), 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
                            bool foundName = false;

                            // Try the per app display name first.
                            if (!appId.empty()) {
                                HKEY hAppKey = NULL;
                                std::wstring appSubKey = L"App\\" + appId;
                                if (RegOpenKeyExW(hKey, appSubKey.c_str(), 0, KEY_READ, &hAppKey) == ERROR_SUCCESS) {
                                    WCHAR buf[1024] = {};
                                    DWORD bufSize = sizeof(buf);
                                    DWORD type = 0;
                                    if (RegQueryValueExW(hAppKey, L"DisplayName", NULL, &type,
                                        (LPBYTE)buf, &bufSize) == ERROR_SUCCESS &&
                                        type == REG_SZ && buf[0] != L'\0')
                                    {
                                        std::wstring raw(buf);
                                        if (raw[0] == L'@') {
                                            WCHAR resolved[1024] = {};
                                            if (SUCCEEDED(SHLoadIndirectString(raw.c_str(), resolved, 1024, NULL)) && resolved[0]) {
                                                proc.friendlyName = resolved;
                                                foundName = true;
                                            }
                                        } else {
                                            proc.friendlyName = raw;
                                            foundName = true;
                                        }
                                    }
                                    RegCloseKey(hAppKey);
                                }
                            }

                            // Fall back to the package level display name.
                            if (!foundName) {
                                WCHAR buf[1024] = {};
                                DWORD bufSize = sizeof(buf);
                                DWORD type = 0;
                                if (RegQueryValueExW(hKey, L"DisplayName", NULL, &type,
                                    (LPBYTE)buf, &bufSize) == ERROR_SUCCESS &&
                                    type == REG_SZ && buf[0] != L'\0')
                                {
                                    std::wstring raw(buf);
                                    if (raw[0] == L'@') {
                                        WCHAR resolved[1024] = {};
                                        if (SUCCEEDED(SHLoadIndirectString(raw.c_str(), resolved, 1024, NULL)) && resolved[0]) {
                                            proc.friendlyName = resolved;
                                        }
                                    } else {
                                        proc.friendlyName = raw;
                                    }
                                }
                            }
                            RegCloseKey(hKey);
                        }
                    }
                }
                CloseHandle(hPkgProc);
            }
            if (!proc.friendlyName.empty()) continue;
        }

        // Then check the known process mapping table.
        auto knownIt = kKnownProcessFriendlyNames.find(lowerName);
        if (knownIt != kKnownProcessFriendlyNames.end()) {
            // Only used when the PE version resource did not supply a better name, so it is kept for later.
        }

        // Then read the FileDescription from the PE version resources.
        HANDLE hProcess = openProcess((HANDLE)(ULONG_PTR)(ULONGLONG)proc.pid);
        if (!hProcess) {
            // When the process cannot be opened, use the known name or the raw name.
            if (proc.friendlyName.empty()) {
                auto ki = kKnownProcessFriendlyNames.find(lowerName);
                proc.friendlyName = (ki != kKnownProcessFriendlyNames.end())
                    ? ki->second : proc.name;
            }
            continue;
        }

        // Remove the exe extension for the fallback display name.
        std::wstring displayName = proc.name;
        if (displayName.size() > 4) {
            std::wstring lower = displayName;
            std::transform(lower.begin(), lower.end(), lower.begin(), ::towlower);
            if (lower.substr(lower.size() - 4) == L".exe") {
                displayName = displayName.substr(0, displayName.size() - 4);
            }
        }

        WCHAR path[MAX_PATH] = {};
        DWORD pathLen = MAX_PATH;
        if (!QueryFullProcessImageNameW(hProcess, 0, path, &pathLen)) {
            CloseHandle(hProcess);
            if (proc.friendlyName.empty()) {
                auto ki = kKnownProcessFriendlyNames.find(lowerName);
                proc.friendlyName = (ki != kKnownProcessFriendlyNames.end())
                    ? ki->second : displayName;
            }
            continue;
        }
        CloseHandle(hProcess);

        std::wstring exePath(path, pathLen);
        proc.exePath = exePath;

        // Check the friendly name cache first.
        auto cacheIt = g_friendlyNameCache.find(exePath);
        if (cacheIt != g_friendlyNameCache.end()) {
            HANDLE hFile = CreateFileW(exePath.c_str(), GENERIC_READ,
                FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
            if (hFile != INVALID_HANDLE_VALUE) {
                FILETIME ftWrite = {};
                if (GetFileTime(hFile, nullptr, nullptr, &ftWrite)) {
                    if (ftWrite.dwLowDateTime == cacheIt->second.lastWriteTime.dwLowDateTime &&
                        ftWrite.dwHighDateTime == cacheIt->second.lastWriteTime.dwHighDateTime) {
                        proc.friendlyName = cacheIt->second.friendlyName;
                        CloseHandle(hFile);
                        if (proc.friendlyName.empty()) proc.friendlyName = displayName;
                        continue;
                    }
                }
                CloseHandle(hFile);
            }
            g_friendlyNameCache.erase(cacheIt);
        }

        // Read the version resource with a multi language fallback.
        DWORD verSize = GetFileVersionInfoSizeW(exePath.c_str(), nullptr);
        if (verSize > 0) {
            std::vector<BYTE> verData(verSize);
            if (GetFileVersionInfoW(exePath.c_str(), 0, verSize, verData.data())) {
                struct LANGANDCODEPAGE {
                    WORD language;
                    WORD codePage;
                };
                LANGANDCODEPAGE* langInfo = nullptr;
                UINT langInfoLen = 0;
                if (VerQueryValueW(verData.data(), L"\\VarFileInfo\\Translation",
                    reinterpret_cast<LPVOID*>(&langInfo), &langInfoLen) && langInfoLen >= 4)
                {
                    // Try several language and codepage combinations for wider coverage.
                    struct { WORD lang; WORD codepage; } langFallbacks[] = {
                        {langInfo[0].language, langInfo[0].codePage},  // System default
                        {0x0409, 0x04B0},  // US English, Unicode
                        {0x0409, 0x04E4},  // US English, codepage 1252
                        {0x0409, 0x0000},  // US English, any codepage
                    };

                    const wchar_t* keysToTry[] = {
                        L"\\StringFileInfo\\%04X%04X\\FileDescription",
                        L"\\StringFileInfo\\%04X%04X\\ProductName",
                    };

                    for (auto& lf : langFallbacks) {
                        if (!proc.friendlyName.empty()) break;
                        for (const auto* fmt : keysToTry) {
                            WCHAR subBlock[128];
                            swprintf_s(subBlock, fmt, lf.lang, lf.codepage);

                            wchar_t* value = nullptr;
                            UINT valueLen = 0;
                            if (VerQueryValueW(verData.data(), subBlock,
                                reinterpret_cast<LPVOID*>(&value), &valueLen) && value && valueLen > 0)
                            {
                                std::wstring fname(value, valueLen - 1);
                                if (!fname.empty()) {
                                    proc.friendlyName = fname;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Then use the MUI cache lookup with the prebuilt map.
        if (proc.friendlyName.empty() && !exePath.empty()) {
            std::wstring lowerExePath = exePath;
            std::transform(lowerExePath.begin(), lowerExePath.end(),
                lowerExePath.begin(), ::towlower);
            auto muiIt = muiCacheMap.find(lowerExePath);
            if (muiIt != muiCacheMap.end()) {
                proc.friendlyName = muiIt->second;
            }
        }

        // Last resort is the known process table.
        if (proc.friendlyName.empty()) {
            auto ki = kKnownProcessFriendlyNames.find(lowerName);
            proc.friendlyName = (ki != kKnownProcessFriendlyNames.end())
                ? ki->second : displayName;
        }

        // Cache the resolved name with its file timestamp.
        HANDLE hFile = CreateFileW(exePath.c_str(), GENERIC_READ,
            FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile != INVALID_HANDLE_VALUE) {
            FILETIME ftWrite = {};
            GetFileTime(hFile, nullptr, nullptr, &ftWrite);
            CloseHandle(hFile);
            FriendlyNameCacheEntry entry;
            entry.friendlyName = proc.friendlyName;
            entry.lastWriteTime = ftWrite;
            g_friendlyNameCache[exePath] = std::move(entry);

            if (g_friendlyNameCache.size() > 500) {
                size_t toRemove = g_friendlyNameCache.size() - 400;
                auto it = g_friendlyNameCache.begin();
                for (size_t i = 0; i < toRemove && it != g_friendlyNameCache.end(); ++i) {
                    it = g_friendlyNameCache.erase(it);
                }
            }
        }
    }

    g_firstRun = false;
    if (processBuffer) HeapFree(GetProcessHeap(), 0, processBuffer);

    // Refresh the PID to friendly name cache.
    g_pidFriendlyNameCache.clear();
    for (const auto& proc : result) {
        if (!proc.friendlyName.empty())
            g_pidFriendlyNameCache[proc.pid] = proc.friendlyName;
        else
            g_pidFriendlyNameCache[proc.pid] = proc.name;
    }

    return result;
}

// Computes the system wide process, thread, and handle counts.
void getProcessSystemCounts(uint32_t& totalProcesses, uint32_t& totalThreads, uint32_t& totalHandles) {
    PVOID processBuffer = NULL;
    ULONG bufferSize = 0x10000;

    for (int retry = 0; retry < 20; retry++) {
        if (processBuffer) HeapFree(GetProcessHeap(), 0, processBuffer);
        processBuffer = HeapAlloc(GetProcessHeap(), 0, bufferSize);
        if (!processBuffer) return;

        NTSTATUS status = NtQuerySystemInformation(
            SystemProcessInformation, processBuffer, bufferSize, &bufferSize);
        if (NT_SUCCESS(status)) break;
        if (status != STATUS_INFO_LENGTH_MISMATCH && status != STATUS_BUFFER_TOO_SMALL) {
            HeapFree(GetProcessHeap(), 0, processBuffer);
            return;
        }
    }

    if (!processBuffer) return;

    totalProcesses = 0;
    totalThreads = 0;
    totalHandles = 0;

    PSYSTEM_PROCESS_INFORMATION spi = PH_FIRST_PROCESS(processBuffer);
    while (spi) {
        totalProcesses++;
        totalThreads += spi->NumberOfThreads;
        totalHandles += spi->HandleCount;
        spi = PH_NEXT_PROCESS(spi);
    }

    HeapFree(GetProcessHeap(), 0, processBuffer);
}
