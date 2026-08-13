#include "exports.h"
#include "json_helpers.h"
#include "common/nt_types.h"
#include "process/process_enumerator.h"
#include "process/process_icons.h"
#include "process/process_terminator.h"
#include "window/window_enumerator.h"
#include "service/service_enumerator.h"
#include "cpu/cpu_stats.h"
#include "gpu/gpu_stats.h"
#include "gpu/gpu_engine_collector.h"
#include "power/power_estimator.h"
#include "disk/disk_permission_checker.h"
#include "disk/disk_stats.h"
#include "common/types.h"
#include "network/network_etw.h"

#include "user/user_filter.h"

#include <string>
#include <vector>
#include <unordered_map>
#include <sstream>
#include <atomic>
#include <mutex>
#include <algorithm>
#include <cwctype>
#include <windows.h>
#include <shellapi.h>
#include <objbase.h>

static std::atomic<bool> g_initialized{false};
static std::string g_lastServiceError;
static std::vector<ProcessInfo> g_cachedProcesses;
static std::mutex g_cacheMutex;
static std::vector<ProcessInfo> g_prevDiffProcesses;
static std::atomic<uint32_t> g_diffSeqCounter{0};

static char* duplicateString(const std::string& s) {
    char* buf = new char[s.size() + 1];
    memcpy(buf, s.c_str(), s.size() + 1);
    return buf;
}

static std::string getErrorMessage(unsigned long code) {
    wchar_t* msg = nullptr;
    DWORD len = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        nullptr, code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (wchar_t*)&msg, 0, nullptr);
    if (len == 0) return "Unknown error (" + std::to_string(code) + ")";
    std::string result = narrowWide(std::wstring(msg, len));
    LocalFree(msg);
    while (!result.empty() && (result.back() == '\r' || result.back() == '\n' || result.back() == ' ' || result.back() == '.'))
        result.pop_back();
    return result;
}

static std::vector<ProcessInfo> enrichProcesses(std::vector<ProcessInfo>& processes) {
    ULONGLONG gpuElapsed100ns = gpuGetElapsed100ns();
    for (auto& p : processes) {
        p.gpuPercent = gpuGetProcessUsageWithElapsed(p.pid, gpuElapsed100ns);
        p.gpuEngine = gpuEngineGetPrimaryEngine(p.pid);
    }

    for (auto& p : processes) {
        double totalDiskMBps = p.diskReadMB + p.diskWriteMB;
        std::string label = computePowerUsageLabel(p.cpuUsage, p.gpuPercent, totalDiskMBps);
        int len = MultiByteToWideChar(CP_UTF8, 0, label.c_str(), -1, nullptr, 0);
        if (len > 0) {
            p.powerUsage.resize(len - 1);
            MultiByteToWideChar(CP_UTF8, 0, label.c_str(), -1, &p.powerUsage[0], len);
        }
    }

    for (auto& p : processes) {
        p.diskPermission = checkDiskPermission(p.pid);
    }

    auto windowGroups = enumerateWindows();
    auto serviceHosts = enumerateServices();

    std::unordered_map<uint32_t, ProcessInfo*> pidLookup;
    for (auto& p : processes) {
        pidLookup[p.pid] = &p;
    }

    for (const auto& wg : windowGroups) {
        auto it = pidLookup.find(wg.pid);
        if (it != pidLookup.end()) {
            it->second->windowTitles.push_back(wg);
        }
    }

    for (const auto& sh : serviceHosts) {
        auto it = pidLookup.find(sh.pid);
        if (it != pidLookup.end()) {
            it->second->serviceDisplayNames.push_back(sh);
        }
    }

    // Post-enrichment: fix svchost.exe friendly names now that services are attached
    for (auto& p : processes) {
        std::wstring lowerName = p.name;
        std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::towlower);
        if (lowerName == L"svchost.exe" && !p.serviceDisplayNames.empty()) {
            std::wstring svcName;
            for (size_t i = 0; i < p.serviceDisplayNames.size(); ++i) {
                if (i > 0) svcName += L", ";
                svcName += p.serviceDisplayNames[i].displayName;
            }
            p.friendlyName = L"Service Host: " + svcName;
        }
    }

    return processes;
}

static uint64_t processFingerprint(const ProcessInfo& p) {
    uint64_t h = 0;
    auto mix = [&](uint64_t v) {
        h ^= v + 0x9e3779b9 + (h << 6) + (h >> 2);
    };
    mix((uint64_t)(p.cpuUsage * 100));
    mix((uint64_t)p.memoryBytes);
    mix((uint64_t)(p.workingSetMB * 100));
    mix((uint64_t)(p.diskReadMB * 100));
    mix((uint64_t)(p.diskWriteMB * 100));
    mix((uint64_t)(p.networkBps * 100));
    mix(p.threadCount);
    mix(p.handleCount);
    mix(p.childCount);
    mix(p.hasChildren ? 1ULL : 0ULL);
    mix(p.isSuspended ? 1ULL : 0ULL);
    return h;
}

extern "C" {

int32_t pl_init() {
    if (g_initialized) return 1;

    if (!ntApiInit()) return 0;

    {
        HANDLE hToken = NULL;
        if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &hToken)) {
            TOKEN_PRIVILEGES tp;
            tp.PrivilegeCount = 1;
            tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
            if (LookupPrivilegeValueA(NULL, "SeDebugPrivilege", &tp.Privileges[0].Luid)) {
                AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), NULL, NULL);
            }
            CloseHandle(hToken);
        }
    }

    g_networkMonitor.start();
    iconCacheInit();
    gpuInit();
    if (gpuEngineInit()) {
        gpuEngineStartCollector();
    }

    g_initialized = true;
    return 1;
}

void pl_shutdown() {
    if (!g_initialized) return;
    g_networkMonitor.stop();
    iconCacheShutdown();
    g_initialized = false;
}

const char* pl_get_stats_json() {
    std::vector<ProcessInfo> processes;
    {
        std::lock_guard<std::mutex> lock(g_cacheMutex);
        processes = g_cachedProcesses;
    }
    if (processes.empty()) {
        processes = enumerateProcesses();
        enrichProcesses(processes);
    }

    SystemStats stats = getSystemStats();

    // Compute process/thread/handle counts from the enumerated process list
    // (avoids a redundant NtQuerySystemInformation call and guarantees consistency)
    uint32_t totalProcesses = (uint32_t)processes.size();
    uint32_t totalThreads = 0;
    uint32_t totalHandles = 0;
    for (const auto& p : processes) {
        totalThreads += p.threadCount;
        totalHandles += p.handleCount;
    }

    double diskReadBps = 0.0, diskWriteBps = 0.0;
    getSystemDiskStats(diskReadBps, diskWriteBps);
    double gpuPercent = gpuGetTotalUsage();

    // Populate extended info for each resource type
    populateDiskInfo(stats);
    populateNetworkInfo(stats);
    populateGpuInfo(stats);

    double netSendBps = 0, netRecvBps = 0;
    getNetworkSpeedStats(netSendBps, netRecvBps);

    std::string json = statsToJson(stats, totalProcesses, totalThreads, totalHandles, diskReadBps, diskWriteBps, gpuPercent, netSendBps, netRecvBps);
    return duplicateString(json);
}

const char* pl_enumerate_processes_diff_json() {
    uint32_t seq = ++g_diffSeqCounter;

    auto processes = enumerateProcesses();
    enrichProcesses(processes);

    // Also cache for stats
    {
        std::lock_guard<std::mutex> lock(g_cacheMutex);
        g_cachedProcesses = processes;
    }

    bool isFullSnapshot = (g_prevDiffProcesses.empty() || seq % 4 == 0);

    if (isFullSnapshot) {
        g_prevDiffProcesses = processes;
        std::string json = "{\"type\":\"processes\",\"data\":" + processesToJson(processes) + ",\"seq\":" + std::to_string(seq) + "}";
        return duplicateString(json);
    }

    // Build diff
    std::unordered_map<uint32_t, size_t> prevByPid;
    for (size_t i = 0; i < g_prevDiffProcesses.size(); i++) {
        prevByPid[g_prevDiffProcesses[i].pid] = i;
    }

    std::vector<const ProcessInfo*> added, updated;
    std::vector<uint32_t> removed;

    for (const auto& p : processes) {
        auto it = prevByPid.find(p.pid);
        if (it == prevByPid.end()) {
            added.push_back(&p);
        } else {
            if (processFingerprint(g_prevDiffProcesses[it->second]) != processFingerprint(p)) {
                updated.push_back(&p);
            }
            prevByPid.erase(it);
        }
    }

    for (const auto& pair : prevByPid) {
        removed.push_back(pair.first);
    }

    g_prevDiffProcesses = processes;

    if (added.empty() && updated.empty() && removed.empty()) {
        return duplicateString("{\"type\":\"nochange\"}");
    }

    std::ostringstream diff;
    diff << "{\"type\":\"processes_diff\",\"seq\":" << seq;

    diff << ",\"added\":[";
    for (size_t i = 0; i < added.size(); i++) {
        if (i > 0) diff << ",";
        diff << processToJson(*added[i]);
    }
    diff << "]";

    diff << ",\"updated\":[";
    for (size_t i = 0; i < updated.size(); i++) {
        if (i > 0) diff << ",";
        diff << processToJson(*updated[i]);
    }
    diff << "]";

    diff << ",\"removed\":[";
    for (size_t i = 0; i < removed.size(); i++) {
        if (i > 0) diff << ",";
        diff << removed[i];
    }
    diff << "]";

    diff << "}";

    return duplicateString(diff.str());
}

int32_t pl_terminate(uint32_t pid) {
    if (pid <= 4) return 0;
    return terminateProcess(pid) ? 1 : 0;
}

int32_t pl_terminate_tree(uint32_t pid) {
    if (pid <= 4) return 0;
    return terminateProcessTree(pid) ? 1 : 0;
}

int32_t pl_terminate_batch(const uint32_t* pids, int32_t count) {
    if (!pids || count <= 0) return 0;
    std::vector<uint32_t> pidVec(pids, pids + count);
    return terminateProcesses(pidVec);
}

int32_t pl_close_window(int64_t hwnd) {
    HWND windowHandle = reinterpret_cast<HWND>(hwnd);
    return PostMessageW(windowHandle, WM_CLOSE, 0, 0) ? 1 : 0;
}

int32_t pl_check_dangerous(uint32_t pid) {
    return isDangerousProcess(pid) ? 1 : 0;
}

const char* pl_get_icon(uint32_t pid) {
    std::string icon = getProcessIconBase64(pid);
    return duplicateString(icon);
}

const char* pl_get_icons_batch_json(const uint32_t* pids, int32_t count) {
    std::ostringstream json;
    json << "{\"icons\":[";
    for (int32_t i = 0; i < count; i++) {
        if (i > 0) json << ",";
        std::string icon = getProcessIconBase64(pids[i]);
        json << "{\"pid\":" << pids[i] << ",\"icon\":" << jsonValue(icon) << "}";
    }
    json << "]}";
    return duplicateString(json.str());
}

const char* pl_get_aumid_icon(const char* aumid) {
    if (!aumid) return duplicateString("");
    std::string a(aumid);
    std::string icon = getAumidIconBase64(a);
    return duplicateString(icon);
}

const char* pl_enumerate_services_json() {
    auto services = enumerateAllServices();
    return duplicateString(servicesListToJson(services));
}

int32_t pl_start_service(const wchar_t* name) {
    if (!name) return 0;
    std::wstring wname(name);
    bool success = startServiceByName(wname);
    unsigned long err = getLastServiceError();
    g_lastServiceError = success ? "" : getErrorMessage(err);
    return success ? 1 : 0;
}

int32_t pl_stop_service(const wchar_t* name) {
    if (!name) return 0;
    std::wstring wname(name);
    bool success = stopServiceByName(wname);
    unsigned long err = getLastServiceError();
    g_lastServiceError = success ? "" : getErrorMessage(err);
    return success ? 1 : 0;
}

int32_t pl_restart_service(const wchar_t* name) {
    if (!name) return 0;
    std::wstring wname(name);
    bool success = restartServiceByName(wname);
    unsigned long err = getLastServiceError();
    g_lastServiceError = success ? "" : getErrorMessage(err);
    return success ? 1 : 0;
}

const char* pl_get_last_service_error() {
    return duplicateString(g_lastServiceError);
}

const char* pl_list_users_json() {
    auto processes = enumerateProcesses();

    std::vector<std::wstring> allUsernames;
    for (const auto& p : processes) {
        if (!p.userName.empty()) {
            allUsernames.push_back(p.userName);
        }
    }

    auto realUsers = filterRealUsers(allUsernames);

    std::ostringstream json;
    json << "{\"data\":[";
    for (size_t i = 0; i < realUsers.size(); i++) {
        if (i > 0) json << ",";
        json << jsonValue(realUsers[i]);
    }
    json << "]}";

    return duplicateString(json.str());
}

int32_t pl_open_services() {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return 0;

    SHELLEXECUTEINFOW sei = {0};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOASYNC;
    sei.lpVerb = L"open";
    sei.lpFile = L"services.msc";
    sei.nShow = SW_SHOW;

    BOOL result = ShellExecuteExW(&sei);

    if (hr == S_OK) CoUninitialize();

    return result ? 1 : 0;
}

int32_t pl_open_properties(uint32_t pid) {
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!hProcess) return 0;

    WCHAR path[MAX_PATH] = {};
    DWORD pathLen = MAX_PATH;
    BOOL ok = QueryFullProcessImageNameW(hProcess, 0, path, &pathLen);
    CloseHandle(hProcess);
    if (!ok) return 0;

    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return 0;

    SHELLEXECUTEINFOW sei = {0};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_INVOKEIDLIST;
    sei.lpVerb = L"properties";
    sei.lpFile = path;
    sei.nShow = SW_SHOW;

    BOOL result = ShellExecuteExW(&sei);

    if (hr == S_OK) CoUninitialize();

    return result ? 1 : 0;
}

int32_t pl_open_file_location(uint32_t pid) {
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!hProcess) return 0;

    WCHAR path[MAX_PATH] = {};
    DWORD pathLen = MAX_PATH;
    BOOL ok = QueryFullProcessImageNameW(hProcess, 0, path, &pathLen);
    CloseHandle(hProcess);
    if (!ok) return 0;

    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return 0;

    // Explorer /select, "path" opens the containing folder with the file selected.
    std::wstring params = L"/select,\"" + std::wstring(path) + L"\"";

    SHELLEXECUTEINFOW sei = {0};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOASYNC;
    sei.lpVerb = L"open";
    sei.lpFile = L"explorer.exe";
    sei.lpParameters = params.c_str();
    sei.nShow = SW_SHOW;

    BOOL result = ShellExecuteExW(&sei);

    if (hr == S_OK) CoUninitialize();

    return result ? 1 : 0;
}

void pl_free_string(const char* str) {
    delete[] const_cast<char*>(str);
}

struct EnumWindowsCtx {
    DWORD pid;
    HWND hwnd;
};

static BOOL CALLBACK enumWindowsCallback(HWND hwnd, LPARAM lParam) {
    auto* ctx = reinterpret_cast<EnumWindowsCtx*>(lParam);
    DWORD windowPid = 0;
    GetWindowThreadProcessId(hwnd, &windowPid);
    if (windowPid == ctx->pid && IsWindowVisible(hwnd)) {
        ctx->hwnd = hwnd;
        return FALSE; // stop
    }
    return TRUE; // continue
}

void pl_open_window_topmost(const wchar_t* appName) {
    std::wstring exePath;
    std::wstring args;

    if (wcscmp(appName, L"resmon") == 0) {
        exePath = L"resmon.exe";
    } else if (wcscmp(appName, L"taskmgr") == 0) {
        exePath = L"Taskmgr.exe";
    } else if (wcscmp(appName, L"services") == 0) {
        exePath = L"mmc.exe";
        args = L" services.msc";
    } else {
        return;
    }

    std::wstring cmdLine = L"\"" + exePath + L"\"" + args;

    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};

    if (!CreateProcessW(nullptr, &cmdLine[0], nullptr, nullptr, FALSE,
                        CREATE_NEW_CONSOLE, nullptr, nullptr, &si, &pi)) {
        return;
    }

    // Find the main window of the launched process (no Sleep needed)
    EnumWindowsCtx ctx = { pi.dwProcessId, nullptr };
    EnumWindows(enumWindowsCallback, reinterpret_cast<LPARAM>(&ctx));

    if (ctx.hwnd) {
        SetForegroundWindow(ctx.hwnd);
        SetWindowPos(ctx.hwnd, HWND_TOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    }

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
}

}
