#include "service/service_enumerator.h"
#include <windows.h>
#include <winsvc.h>

#include <vector>
#include <string>
#include <thread>
#include <chrono>

// Enables a Windows privilege on the process token, needed for some service start and stop operations
static bool enablePrivilege(const char* privName) {
    HANDLE hToken = NULL;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken))
        return false;

    TOKEN_PRIVILEGES tp = {};
    tp.PrivilegeCount = 1;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    if (!LookupPrivilegeValueA(NULL, privName, &tp.Privileges[0].Luid)) {
        CloseHandle(hToken);
        return false;
    }

    BOOL ok = AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), NULL, NULL);
    DWORD err = GetLastError();
    CloseHandle(hToken);
    return ok && err == ERROR_SUCCESS;
}

// Legacy helper that maps svchost services to their hosting process
std::vector<ServiceHostInfo> enumerateServices() {
    std::vector<ServiceHostInfo> result;

    SC_HANDLE hScm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_ENUMERATE_SERVICE);
    if (!hScm) return result;

    DWORD bufSize = 0;
    DWORD serviceCount = 0;
    DWORD resumeHandle = 0;

    EnumServicesStatusExW(
        hScm, SC_ENUM_PROCESS_INFO,
        SERVICE_WIN32, SERVICE_STATE_ALL,
        nullptr, 0, &bufSize, &serviceCount, &resumeHandle, nullptr);

    if (GetLastError() != ERROR_MORE_DATA) {
        CloseServiceHandle(hScm);
        return result;
    }

    std::vector<BYTE> buffer(bufSize);
    auto* services = reinterpret_cast<ENUM_SERVICE_STATUS_PROCESSW*>(buffer.data());

    if (!EnumServicesStatusExW(
        hScm, SC_ENUM_PROCESS_INFO,
        SERVICE_WIN32, SERVICE_STATE_ALL,
        buffer.data(), bufSize, &bufSize, &serviceCount, &resumeHandle, nullptr))
    {
        CloseServiceHandle(hScm);
        return result;
    }

    for (DWORD i = 0; i < serviceCount; i++) {
        const auto& entry = services[i];
        DWORD pid = entry.ServiceStatusProcess.dwProcessId;
        if (pid == 0) continue;

        ServiceHostInfo she;
        she.pid = static_cast<uint32_t>(pid);
        she.displayName = entry.lpDisplayName ? entry.lpDisplayName : L"";
        if (!she.displayName.empty()) {
            result.push_back(std::move(she));
        }
    }

    CloseServiceHandle(hScm);
    return result;
}

// Turns a service state code into a readable label
static std::wstring ServiceStateToString(DWORD state) {
    switch (state) {
        case SERVICE_STOPPED:          return L"Stopped";
        case SERVICE_START_PENDING:    return L"Restarting";
        case SERVICE_STOP_PENDING:     return L"Stopping";
        case SERVICE_RUNNING:          return L"Running";
        case SERVICE_CONTINUE_PENDING: return L"Continuing";
        case SERVICE_PAUSE_PENDING:    return L"Pausing";
        case SERVICE_PAUSED:           return L"Paused";
        default:                       return L"Unknown";
    }
}

// Turns a service type bitmask into a readable label matching System Informer
static std::wstring ServiceTypeToString(DWORD type) {
    DWORD base = type & ~SERVICE_INTERACTIVE_PROCESS;
    bool interactive = (type & SERVICE_INTERACTIVE_PROCESS) != 0;

    if (type & SERVICE_DRIVER) {
        if (type & SERVICE_FILE_SYSTEM_DRIVER) return L"FS driver";
        return L"Driver";
    }
    if (type & SERVICE_PKG_SERVICE) {
        if (base == SERVICE_WIN32_OWN_PROCESS) return L"Package own process";
        if (base == SERVICE_WIN32_SHARE_PROCESS) return L"Package share process";
    }
    if (type & SERVICE_USER_OWN_PROCESS) {
        if (type & SERVICE_USERSERVICE_INSTANCE) return L"User own process (instance)";
        return L"User own process";
    }
    if (type & SERVICE_USER_SHARE_PROCESS) {
        if (type & SERVICE_USERSERVICE_INSTANCE) return L"User share process (instance)";
        return L"User share process";
    }
    if (base == SERVICE_WIN32_OWN_PROCESS) return interactive ? L"Own interactive process" : L"Own process";
    if (base == SERVICE_WIN32_SHARE_PROCESS) return interactive ? L"Share interactive process" : L"Share process";

    return L"Unknown";
}

// Reads the service description through QueryServiceConfig2
static std::wstring GetServiceDescription(SC_HANDLE hScm, const std::wstring& serviceName) {
    SC_HANDLE hSvc = OpenServiceW(hScm, serviceName.c_str(), SERVICE_QUERY_CONFIG);
    if (!hSvc) return L"";

    DWORD bufSize = 0;
    QueryServiceConfig2W(hSvc, SERVICE_CONFIG_DESCRIPTION, nullptr, 0, &bufSize);

    if (GetLastError() != ERROR_MORE_DATA) {
        CloseServiceHandle(hSvc);
        return L"";
    }

    std::vector<BYTE> buffer(bufSize);
    auto* desc = reinterpret_cast<SERVICE_DESCRIPTIONW*>(buffer.data());

    if (QueryServiceConfig2W(hSvc, SERVICE_CONFIG_DESCRIPTION, buffer.data(), bufSize, &bufSize)) {
        CloseServiceHandle(hSvc);
        return desc->lpDescription ? desc->lpDescription : L"";
    }

    CloseServiceHandle(hSvc);
    return L"";
}

// Extracts the service group from the binary path, the same way Task Manager fills the Group column
static std::wstring GetServiceGroup(SC_HANDLE hScm, const std::wstring& serviceName) {
    SC_HANDLE hSvc = OpenServiceW(hScm, serviceName.c_str(), SERVICE_QUERY_CONFIG);
    if (!hSvc) return L"";

    DWORD bufSize = 0;
    QueryServiceConfigW(hSvc, nullptr, 0, &bufSize);

    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
        CloseServiceHandle(hSvc);
        return L"";
    }

    std::vector<BYTE> buffer(bufSize);
    auto* config = reinterpret_cast<QUERY_SERVICE_CONFIGW*>(buffer.data());

    if (!QueryServiceConfigW(hSvc, config, bufSize, &bufSize)) {
        CloseServiceHandle(hSvc);
        return L"";
    }

    CloseServiceHandle(hSvc);

    if (!config->lpBinaryPathName) return L"";

    std::wstring path = config->lpBinaryPathName;

    // Locate the -k flag that introduces the group name in the path
    size_t kPos = path.find(L"-k ");
    if (kPos == std::wstring::npos) {
        kPos = path.find(L"-k\t");
    }
    if (kPos == std::wstring::npos) {
        kPos = path.find(L"-k\"");
    }
    if (kPos == std::wstring::npos) return L"";

    size_t start = kPos + 3;
    // Skip any spaces that follow the flag
    while (start < path.size() && (path[start] == L' ' || path[start] == L'\t')) {
        start++;
    }
    if (start >= path.size()) return L"";

    // Quoted group names run to the closing quote
    if (path[start] == L'"') {
        start++;
        size_t end = path.find(L'"', start);
        if (end == std::wstring::npos) return L"";
        return path.substr(start, end - start);
    }

    // Unquoted group names run until the next space or the end of the path
    size_t end = start;
    while (end < path.size() && path[end] != L' ' && path[end] != L'\t') {
        end++;
    }
    return path.substr(start, end - start);
}

std::vector<ServiceInfo> enumerateAllServices() {
    std::vector<ServiceInfo> result;

    SC_HANDLE hScm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_ENUMERATE_SERVICE | SC_MANAGER_CONNECT);
    if (!hScm) return result;

    DWORD bufSize = 0;
    DWORD serviceCount = 0;
    DWORD resumeHandle = 0;

    // Cover own and share process services plus per user service templates like CDPUserSvc
    const DWORD serviceFilter = SERVICE_WIN32 | 0x40;

    // First call only asks how much space the result needs
    EnumServicesStatusExW(
        hScm, SC_ENUM_PROCESS_INFO,
        serviceFilter, SERVICE_STATE_ALL,
        nullptr, 0, &bufSize, &serviceCount, &resumeHandle, nullptr);

    if (GetLastError() != ERROR_MORE_DATA) {
        CloseServiceHandle(hScm);
        return result;
    }

    std::vector<BYTE> buffer(bufSize);
    auto* services = reinterpret_cast<ENUM_SERVICE_STATUS_PROCESSW*>(buffer.data());

    if (!EnumServicesStatusExW(
        hScm, SC_ENUM_PROCESS_INFO,
        serviceFilter, SERVICE_STATE_ALL,
        buffer.data(), bufSize, &bufSize, &serviceCount, &resumeHandle, nullptr))
    {
        CloseServiceHandle(hScm);
        return result;
    }

    result.reserve(serviceCount);
    for (DWORD i = 0; i < serviceCount; i++) {
        const auto& entry = services[i];

        ServiceInfo si;
        si.serviceName = entry.lpServiceName ? entry.lpServiceName : L"";
        si.displayName = entry.lpDisplayName ? entry.lpDisplayName : L"";
        si.pid = entry.ServiceStatusProcess.dwProcessId;
        si.status = ServiceStateToString(entry.ServiceStatusProcess.dwCurrentState);
        si.statusCode = entry.ServiceStatusProcess.dwCurrentState;
        si.type = ServiceTypeToString(entry.ServiceStatusProcess.dwServiceType);

        // Read the description, which is empty for many services
        si.description = GetServiceDescription(hScm, si.serviceName);

        // Extract the service group for display
        si.group = GetServiceGroup(hScm, si.serviceName);

        result.push_back(std::move(si));
    }

    CloseServiceHandle(hScm);
    return result;
}

// Stores the last error reported by a service control action
static unsigned long s_lastServiceError = 0;

unsigned long getLastServiceError() {
    return s_lastServiceError;
}

static void setLastServiceError() {
    s_lastServiceError = GetLastError();
}

bool startServiceByName(const std::wstring& serviceName) {
    s_lastServiceError = 0;
    enablePrivilege("SeServiceStartPrivilege");

    SC_HANDLE hScm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
    if (!hScm) { setLastServiceError(); return false; }

    SC_HANDLE hSvc = OpenServiceW(hScm, serviceName.c_str(), SERVICE_START);
    if (!hSvc) { setLastServiceError(); CloseServiceHandle(hScm); return false; }

    bool success = ::StartServiceW(hSvc, 0, nullptr) != 0;
    if (!success) {
        setLastServiceError();
        // Treat an already running service as a successful start
        if (GetLastError() == ERROR_SERVICE_ALREADY_RUNNING) {
            success = true;
            s_lastServiceError = 0;
        }
    }

    CloseServiceHandle(hSvc);
    CloseServiceHandle(hScm);
    return success;
}

bool stopServiceByName(const std::wstring& serviceName) {
    s_lastServiceError = 0;
    enablePrivilege("SeServiceStartPrivilege");
    enablePrivilege("SeShutdownPrivilege");

    SC_HANDLE hScm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
    if (!hScm) { setLastServiceError(); return false; }

    SC_HANDLE hSvc = OpenServiceW(hScm, serviceName.c_str(), SERVICE_STOP);
    if (!hSvc) { setLastServiceError(); CloseServiceHandle(hScm); return false; }

    SERVICE_STATUS_PROCESS status;
    bool success = ControlService(hSvc, SERVICE_CONTROL_STOP, reinterpret_cast<SERVICE_STATUS*>(&status)) != 0;
    if (!success) setLastServiceError();

    CloseServiceHandle(hSvc);
    CloseServiceHandle(hScm);
    return success;
}

bool restartServiceByName(const std::wstring& serviceName) {
    // Try to stop the service first
    bool stopSucceeded = stopServiceByName(serviceName);

    if (!stopSucceeded) {
        // A failed stop is fine if the service was already stopped
        SC_HANDLE hScm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
        if (!hScm) return false;

        SC_HANDLE hSvc = OpenServiceW(hScm, serviceName.c_str(), SERVICE_QUERY_STATUS);
        if (!hSvc) {
            CloseServiceHandle(hScm);
            return false;
        }

        SERVICE_STATUS_PROCESS status = {};
        DWORD bytesNeeded = 0;
        BOOL ok = QueryServiceStatusEx(hSvc, SC_STATUS_PROCESS_INFO, reinterpret_cast<BYTE*>(&status), sizeof(status), &bytesNeeded);
        CloseServiceHandle(hSvc);
        CloseServiceHandle(hScm);

        // Any other state means the stop failed for a real reason like access denied
        if (!ok || status.dwCurrentState != SERVICE_STOPPED) {
            return false;
        }
        // The service was already stopped, so continue to the start step
    }

    // Wait up to five seconds for the service to reach the stopped state
    for (int i = 0; i < 50; i++) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));

        SC_HANDLE hScm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
        if (!hScm) continue;

        SC_HANDLE hSvc = OpenServiceW(hScm, serviceName.c_str(), SERVICE_QUERY_STATUS);
        if (!hSvc) { CloseServiceHandle(hScm); continue; }

        SERVICE_STATUS_PROCESS status = {};
        DWORD bytesNeeded = 0;
        BOOL ok = QueryServiceStatusEx(hSvc, SC_STATUS_PROCESS_INFO, reinterpret_cast<BYTE*>(&status), sizeof(status), &bytesNeeded);
        CloseServiceHandle(hSvc);
        CloseServiceHandle(hScm);

        if (ok && status.dwCurrentState == SERVICE_STOPPED) {
            break;
        }
    }

    // Start the service again
    return startServiceByName(serviceName);
}


