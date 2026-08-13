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

#include <iostream>
#include <string>
#include <sstream>
#include <iomanip>
#include <vector>
#include <thread>
#include <mutex>
#include <atomic>
#include <unordered_map>
#include <cctype>
#include <shellapi.h>
#include <objbase.h>

// JSON helpers, unchanged from the original.

static std::string escapeJsonString(const std::wstring& wstr) {
    std::string result;
    for (wchar_t wc : wstr) {
        if (wc == L'"') result += "\\\"";
        else if (wc == L'\\') result += "\\\\";
        else if (wc == L'\n') result += "\\n";
        else if (wc == L'\r') result += "\\r";
        else if (wc == L'\t') result += "\\t";
        else if (wc < 0x20) {
            char buf[8];
            snprintf(buf, sizeof(buf), "\\u%04x", (unsigned int)wc);
            result += buf;
        }
        else if (wc < 0x80) {
            result += (char)wc;
        }
        else {
            if (wc >= 0xD800 && wc <= 0xDBFF) continue;
            if (wc >= 0xDC00 && wc <= 0xDFFF) continue;
            if (wc < 0x800) {
                result += (char)(0xC0 | (wc >> 6));
                result += (char)(0x80 | (wc & 0x3F));
            } else if (wc < 0x10000) {
                result += (char)(0xE0 | (wc >> 12));
                result += (char)(0x80 | ((wc >> 6) & 0x3F));
                result += (char)(0x80 | (wc & 0x3F));
            } else {
                result += (char)(0xF0 | ((unsigned int)wc >> 18));
                result += (char)(0x80 | (((unsigned int)wc >> 12) & 0x3F));
                result += (char)(0x80 | (((unsigned int)wc >> 6) & 0x3F));
                result += (char)(0x80 | ((unsigned int)wc & 0x3F));
            }
        }
    }
    return result;
}

static std::string jsonValue(double val) {
    std::ostringstream ss;
    ss << std::fixed << std::setprecision(1) << val;
    return ss.str();
}

static std::string jsonValue(int val) {
    return std::to_string(val);
}

static std::string jsonValue(unsigned int val) {
    return std::to_string(val);
}

static std::string jsonValue(uint64_t val) {
    return std::to_string(val);
}

static std::string jsonValue(bool val) {
    return val ? "true" : "false";
}

static std::string jsonValue(const std::string& val) {
    return "\"" + val + "\"";
}

static std::string jsonValue(const std::wstring& val) {
    if (val.empty()) return "\"\"";
    return "\"" + escapeJsonString(val) + "\"";
}

// Types and helpers for the stdio protocol.

using Params = std::unordered_map<std::string, std::string>;

static std::wstring utf8ToWide(const std::string& utf8) {
    if (utf8.empty()) return L"";
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), (int)utf8.size(), nullptr, 0);
    if (len <= 0) return L"";
    std::wstring result(len, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), (int)utf8.size(), &result[0], len);
    return result;
}

static std::string narrowWide(const std::wstring& ws) {
    if (ws.empty()) return "";
    int len = WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), nullptr, 0, nullptr, nullptr);
    if (len <= 0) return "";
    std::string result(len, '\0');
    WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), &result[0], len, nullptr, nullptr);
    return result;
}

static std::string trim(const std::string& s) {
    size_t start = 0;
    while (start < s.size() && std::isspace((unsigned char)s[start])) start++;
    size_t end = s.size();
    while (end > start && std::isspace((unsigned char)s[end - 1])) end--;
    return s.substr(start, end - start);
}

static Params parseJsonObject(const std::string& json) {
    Params params;
    size_t pos = json.find('{');
    if (pos == std::string::npos) return params;
    pos++;

    while (pos < json.size()) {
        while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\n' || json[pos] == '\r' || json[pos] == ',')) pos++;
        if (pos >= json.size() || json[pos] == '}') break;

        if (json[pos] != '"') break;
        pos++;
        std::string key;
        while (pos < json.size() && json[pos] != '"') {
            if (json[pos] == '\\') { pos++; if (pos < json.size()) key += json[pos]; }
            else key += json[pos];
            pos++;
        }
        if (pos >= json.size()) break;
        pos++;

        while (pos < json.size() && (json[pos] == ' ' || json[pos] == ':')) pos++;
        if (pos >= json.size()) break;

        if (json[pos] == '"') {
            pos++;
            std::string value;
            while (pos < json.size() && json[pos] != '"') {
                if (json[pos] == '\\') { pos++; if (pos < json.size()) value += json[pos]; }
                else value += json[pos];
                pos++;
            }
            pos++;
            params[key] = value;
        } else if (json[pos] == '[') {
            size_t depth = 1;
            size_t start = pos;
            pos++;
            while (pos < json.size() && depth > 0) {
                if (json[pos] == '[') depth++;
                else if (json[pos] == ']') depth--;
                pos++;
            }
            params[key] = json.substr(start, pos - start);
        } else {
            std::string value;
            while (pos < json.size() && json[pos] != ',' && json[pos] != '}' && json[pos] != ' ' && json[pos] != '\t' && json[pos] != '\n') {
                value += json[pos];
                pos++;
            }
            params[key] = value;
        }
    }
    return params;
}

static std::vector<uint32_t> parseIntArray(const std::string& arrStr) {
    std::vector<uint32_t> result;
    size_t pos = arrStr.find('[');
    if (pos == std::string::npos) return result;
    pos++;
    while (pos < arrStr.size()) {
        while (pos < arrStr.size() && (arrStr[pos] == ' ' || arrStr[pos] == ',')) pos++;
        if (pos >= arrStr.size() || arrStr[pos] == ']') break;
        std::string num;
        while (pos < arrStr.size() && std::isdigit((unsigned char)arrStr[pos])) {
            num += arrStr[pos];
            pos++;
        }
        if (!num.empty()) result.push_back((uint32_t)std::stoul(num));
    }
    return result;
}

static int getIntParam(const Params& params, const std::string& key, int defaultVal = 0) {
    auto it = params.find(key);
    if (it == params.end() || it->second.empty()) return defaultVal;
    try { return std::stoi(it->second); }
    catch (...) { return defaultVal; }
}

static std::string getStrParam(const Params& params, const std::string& key, const std::string& defaultVal = "") {
    auto it = params.find(key);
    return (it != params.end()) ? it->second : defaultVal;
}

// State shared between the push thread and command handlers.

static std::mutex g_dataMutex;
static std::vector<ProcessInfo> g_latestProcesses;
static std::mutex g_stdoutMutex;
static std::atomic<bool> g_running{true};
static std::atomic<uint32_t> g_seqCounter{0};
static std::vector<ProcessInfo> g_prevProcesses;

static uint64_t processFingerprint(const ProcessInfo& p) {
    uint64_t h = 0;
    auto mix = [&](uint64_t v) {
        h ^= v + 0x9e3779b9 + (h << 6) + (h >> 2);
    };
    mix((uint64_t)p.cpuUsage * 100);
    mix((uint64_t)p.memoryBytes);
    mix((uint64_t)p.workingSetMB * 100);
    mix((uint64_t)p.diskReadMB * 100);
    mix((uint64_t)p.diskWriteMB * 100);
    mix((uint64_t)p.networkBps * 100);
    mix(p.threadCount);
    mix(p.handleCount);
    mix(p.childCount);
    mix(p.hasChildren ? 1ULL : 0ULL);
    mix(p.isSuspended ? 1ULL : 0ULL);
    return h;
}

// JSON serialization for push events, extracted from the old HTTP handlers.

static std::string processesToJson(const std::vector<ProcessInfo>& processes) {
    std::ostringstream json;
    json << "[";
    for (size_t i = 0; i < processes.size(); i++) {
        const auto& p = processes[i];
        if (i > 0) json << ",";
        json << "{";
        json << "\"pid\":" << jsonValue(p.pid) << ",";
        json << "\"parentPid\":" << jsonValue(p.parentPid) << ",";
        json << "\"name\":" << jsonValue(p.name) << ",";
        json << "\"exePath\":" << jsonValue(p.exePath) << ",";
        json << "\"friendlyName\":" << jsonValue(p.friendlyName) << ",";
        json << "\"detailName\":" << jsonValue(p.detailName) << ",";
        json << "\"aumid\":" << jsonValue(p.aumid) << ",";
        json << "\"userName\":" << jsonValue(p.userName) << ",";
        json << "\"status\":" << jsonValue(p.status) << ",";
        json << "\"statusType\":" << jsonValue(p.statusType) << ",";
        json << "\"basePriority\":" << jsonValue(p.basePriority) << ",";
        json << "\"threadCount\":" << jsonValue(p.threadCount) << ",";
        json << "\"handleCount\":" << jsonValue(p.handleCount) << ",";
        json << "\"sessionId\":" << jsonValue(p.sessionId) << ",";
        json << "\"cpuUsage\":" << jsonValue(p.cpuUsage) << ",";
        json << "\"memoryMB\":" << jsonValue(p.memoryMB) << ",";
        json << "\"virtualMemoryMB\":" << jsonValue(p.virtualMemoryMB) << ",";
        json << "\"memoryBytes\":" << jsonValue(p.memoryBytes) << ",";
        json << "\"workingSetMB\":" << jsonValue(p.workingSetMB) << ",";
        json << "\"memoryAccessDenied\":" << jsonValue(p.memoryAccessDenied) << ",";
        json << "\"diskReadMB\":" << jsonValue(p.diskReadMB) << ",";
        json << "\"diskWriteMB\":" << jsonValue(p.diskWriteMB) << ",";
        json << "\"networkConnections\":" << jsonValue(p.networkConnections) << ",";
        json << "\"networkBps\":" << jsonValue(p.networkBps) << ",";
        json << "\"gpuPercent\":" << jsonValue(p.gpuPercent) << ",";
        json << "\"gpuEngine\":" << jsonValue(p.gpuEngine) << ",";
        json << "\"powerUsage\":" << jsonValue(p.powerUsage) << ",";
        json << "\"diskPermission\":" << jsonValue(p.diskPermission) << ",";
        json << "\"uacVirtualization\":" << jsonValue(p.uacVirtualization) << ",";
        json << "\"isWow64\":" << jsonValue(p.isWow64) << ",";
        json << "\"isProtected\":" << jsonValue(p.isProtected) << ",";
        json << "\"isSuspended\":" << jsonValue(p.isSuspended) << ",";
        json << "\"isElevated\":" << jsonValue(p.isElevated) << ",";
        json << "\"isBackground\":" << jsonValue(p.isBackground) << ",";
        json << "\"isSystemProcess\":" << jsonValue(p.isSystemProcess) << ",";
        json << "\"hasVisibleWindow\":" << jsonValue(p.hasVisibleWindow) << ",";
        json << "\"hasIdeMatch\":" << jsonValue(p.hasIdeMatch) << ",";
        json << "\"hasChildren\":" << jsonValue(p.hasChildren) << ",";
        json << "\"childCount\":" << jsonValue(p.childCount) << ",";

        json << "\"windowTitles\":[";
        for (size_t w = 0; w < p.windowTitles.size(); w++) {
            if (w > 0) json << ",";
            json << "{\"title\":" << jsonValue(p.windowTitles[w].title)
                 << ",\"hwnd\":" << jsonValue(p.windowTitles[w].hwnd)
                 << ",\"pid\":" << jsonValue(p.windowTitles[w].pid) << "}";
        }
        json << "],";

        json << "\"serviceDisplayNames\":[";
        for (size_t s = 0; s < p.serviceDisplayNames.size(); s++) {
            if (s > 0) json << ",";
            json << jsonValue(p.serviceDisplayNames[s].displayName);
        }
        json << "]";

        json << "}";
    }
    json << "]";
    return json.str();
}

static std::string statsToJson(const SystemStats& stats, uint32_t totalProcesses, uint32_t totalThreads,
                                uint32_t totalHandles, double diskReadBps, double diskWriteBps, double gpuPercent,
                                double netSendBps = 0, double netRecvBps = 0) {
    std::ostringstream json;
    json << "{";
    json << "\"cpuUsagePercent\":" << jsonValue(stats.cpuUsagePercent) << ",";
    json << "\"cpuKernelPercent\":" << jsonValue(stats.cpuKernelPercent) << ",";
    json << "\"cpuUserPercent\":" << jsonValue(stats.cpuUserPercent) << ",";
    json << "\"totalProcesses\":" << jsonValue(totalProcesses) << ",";
    json << "\"totalThreads\":" << jsonValue(totalThreads) << ",";
    json << "\"totalHandles\":" << jsonValue(totalHandles) << ",";
    json << "\"totalPhysicalMB\":" << jsonValue(stats.totalPhysicalMB) << ",";
    json << "\"usedPhysicalMB\":" << jsonValue(stats.usedPhysicalMB) << ",";
    json << "\"availablePhysicalMB\":" << jsonValue(stats.availablePhysicalMB) << ",";
    json << "\"commitChargeMB\":" << jsonValue(stats.commitChargeMB) << ",";
    json << "\"commitLimitMB\":" << jsonValue(stats.commitLimitMB) << ",";
    json << "\"diskReadMBps\":" << jsonValue(diskReadBps / (1024.0 * 1024.0)) << ",";
    json << "\"diskWriteMBps\":" << jsonValue(diskWriteBps / (1024.0 * 1024.0)) << ",";
    json << "\"gpuUsagePercent\":" << jsonValue(gpuPercent) << ",";
    json << "\"netSendBps\":" << jsonValue(netSendBps) << ",";
    json << "\"netRecvBps\":" << jsonValue(netRecvBps) << ",";
    json << "\"cpuSpeedMHz\":" << jsonValue(stats.cpuSpeedMHz) << ",";
    json << "\"cpuBaseSpeedMHz\":" << jsonValue(stats.cpuBaseSpeedMHz) << ",";
    json << "\"cpuName\":" << jsonValue(stats.cpuName) << ",";
    json << "\"cpuSockets\":" << jsonValue(stats.cpuSockets) << ",";
    json << "\"cpuCores\":" << jsonValue(stats.cpuCores) << ",";
    json << "\"cpuLogicalProcessors\":" << jsonValue(stats.cpuLogicalProcessors) << ",";
    json << "\"cpuVirtualization\":" << jsonValue(stats.cpuVirtualization) << ",";
    json << "\"cpuL1CacheKB\":" << jsonValue(stats.cpuL1CacheKB) << ",";
    json << "\"cpuL2CacheKB\":" << jsonValue(stats.cpuL2CacheKB) << ",";
    json << "\"cpuL3CacheKB\":" << jsonValue(stats.cpuL3CacheKB) << ",";
    json << "\"uptimeSeconds\":" << jsonValue(stats.uptimeSeconds) << ",";
    json << "\"memoryCompressedMB\":" << jsonValue(stats.memoryCompressedMB) << ",";
    json << "\"memoryCachedMB\":" << jsonValue(stats.memoryCachedMB) << ",";
    json << "\"memoryPagedPoolMB\":" << jsonValue(stats.memoryPagedPoolMB) << ",";
    json << "\"memoryNonPagedPoolMB\":" << jsonValue(stats.memoryNonPagedPoolMB) << ",";
    json << "\"memorySpeedMHz\":" << jsonValue(stats.memorySpeedMHz) << ",";
    json << "\"memorySlotsUsed\":" << jsonValue(stats.memorySlotsUsed) << ",";
    json << "\"memorySlotsTotal\":" << jsonValue(stats.memorySlotsTotal) << ",";
    json << "\"memoryFormFactor\":" << jsonValue(stats.memoryFormFactor) << ",";
    json << "\"memoryType\":" << jsonValue(stats.memoryType) << ",";
    json << "\"memoryHardwareReservedMB\":" << jsonValue(stats.memoryHardwareReservedMB) << ",";
    json << "\"diskActivePercent\":" << jsonValue(stats.diskActivePercent) << ",";
    json << "\"diskAvgResponseMs\":" << jsonValue(stats.diskAvgResponseMs) << ",";
    json << "\"diskCapacityBytes\":" << jsonValue(stats.diskCapacityBytes) << ",";
    json << "\"diskIsSystem\":" << jsonValue(stats.diskIsSystem) << ",";
    json << "\"diskHasPageFile\":" << jsonValue(stats.diskHasPageFile) << ",";
    json << "\"diskType\":" << jsonValue(stats.diskType) << ",";
    json << "\"diskModel\":" << jsonValue(stats.diskModel) << ",";
    json << "\"netAdapterName\":" << jsonValue(stats.netAdapterName) << ",";
    json << "\"netNicModel\":" << jsonValue(stats.netNicModel) << ",";
    json << "\"netSsid\":" << jsonValue(stats.netSsid) << ",";
    json << "\"netConnectionType\":" << jsonValue(stats.netConnectionType) << ",";
    json << "\"netIpv4Address\":" << jsonValue(stats.netIpv4Address) << ",";
    json << "\"netIpv6Address\":" << jsonValue(stats.netIpv6Address) << ",";
    json << "\"netSignalPercent\":" << jsonValue(stats.netSignalPercent) << ",";
    json << "\"gpuDedicatedMB\":" << jsonValue(stats.gpuDedicatedMB) << ",";
    json << "\"gpuSharedMB\":" << jsonValue(stats.gpuSharedMB) << ",";
    json << "\"gpuTotalMemoryMB\":" << jsonValue(stats.gpuTotalMemoryMB) << ",";
    json << "\"gpuDedicatedTotalMB\":" << jsonValue(stats.gpuDedicatedTotalMB) << ",";
    json << "\"gpuSharedTotalMB\":" << jsonValue(stats.gpuSharedTotalMB) << ",";
    json << "\"gpuDriverVersion\":" << jsonValue(stats.gpuDriverVersion) << ",";
    json << "\"gpuName\":" << jsonValue(stats.gpuName) << ",";
    json << "\"gpuDriverDate\":" << jsonValue(stats.gpuDriverDate) << ",";
    json << "\"gpuDirectXVersion\":" << jsonValue(stats.gpuDirectXVersion) << ",";
    json << "\"gpuPhysicalLocation\":" << jsonValue(stats.gpuPhysicalLocation) << ",";
    json << "\"gpuHardwareReservedMB\":" << jsonValue(stats.gpuHardwareReservedMB);
    json << "}";
    return json.str();
}

static std::string processToJson(const ProcessInfo& p) {
    std::ostringstream json;
    json << "{";
    json << "\"pid\":" << jsonValue(p.pid) << ",";
    json << "\"parentPid\":" << jsonValue(p.parentPid) << ",";
    json << "\"name\":" << jsonValue(p.name) << ",";
    json << "\"exePath\":" << jsonValue(p.exePath) << ",";
    json << "\"friendlyName\":" << jsonValue(p.friendlyName) << ",";
    json << "\"detailName\":" << jsonValue(p.detailName) << ",";
    json << "\"aumid\":" << jsonValue(p.aumid) << ",";
    json << "\"userName\":" << jsonValue(p.userName) << ",";
    json << "\"status\":" << jsonValue(p.status) << ",";
    json << "\"statusType\":" << jsonValue(p.statusType) << ",";
    json << "\"basePriority\":" << jsonValue(p.basePriority) << ",";
    json << "\"threadCount\":" << jsonValue(p.threadCount) << ",";
    json << "\"handleCount\":" << jsonValue(p.handleCount) << ",";
    json << "\"sessionId\":" << jsonValue(p.sessionId) << ",";
    json << "\"cpuUsage\":" << jsonValue(p.cpuUsage) << ",";
    json << "\"memoryMB\":" << jsonValue(p.memoryMB) << ",";
    json << "\"virtualMemoryMB\":" << jsonValue(p.virtualMemoryMB) << ",";
    json << "\"memoryBytes\":" << jsonValue(p.memoryBytes) << ",";
    json << "\"workingSetMB\":" << jsonValue(p.workingSetMB) << ",";
    json << "\"memoryAccessDenied\":" << jsonValue(p.memoryAccessDenied) << ",";
    json << "\"diskReadMB\":" << jsonValue(p.diskReadMB) << ",";
    json << "\"diskWriteMB\":" << jsonValue(p.diskWriteMB) << ",";
    json << "\"networkConnections\":" << jsonValue(p.networkConnections) << ",";
    json << "\"networkBps\":" << jsonValue(p.networkBps) << ",";
    json << "\"gpuPercent\":" << jsonValue(p.gpuPercent) << ",";
    json << "\"gpuEngine\":" << jsonValue(p.gpuEngine) << ",";
    json << "\"powerUsage\":" << jsonValue(p.powerUsage) << ",";
    json << "\"diskPermission\":" << jsonValue(p.diskPermission) << ",";
    json << "\"uacVirtualization\":" << jsonValue(p.uacVirtualization) << ",";
    json << "\"isWow64\":" << jsonValue(p.isWow64) << ",";
    json << "\"isProtected\":" << jsonValue(p.isProtected) << ",";
    json << "\"isSuspended\":" << jsonValue(p.isSuspended) << ",";
    json << "\"isElevated\":" << jsonValue(p.isElevated) << ",";
    json << "\"isBackground\":" << jsonValue(p.isBackground) << ",";
    json << "\"isSystemProcess\":" << jsonValue(p.isSystemProcess) << ",";
    json << "\"hasVisibleWindow\":" << jsonValue(p.hasVisibleWindow) << ",";
    json << "\"hasIdeMatch\":" << jsonValue(p.hasIdeMatch) << ",";
    json << "\"hasChildren\":" << jsonValue(p.hasChildren) << ",";
    json << "\"childCount\":" << jsonValue(p.childCount) << ",";

    json << "\"windowTitles\":[";
    for (size_t w = 0; w < p.windowTitles.size(); w++) {
        if (w > 0) json << ",";
        json << "{\"title\":" << jsonValue(p.windowTitles[w].title)
             << ",\"hwnd\":" << jsonValue(p.windowTitles[w].hwnd)
             << ",\"pid\":" << jsonValue(p.windowTitles[w].pid) << "}";
    }
    json << "],";

    json << "\"serviceDisplayNames\":[";
    for (size_t s = 0; s < p.serviceDisplayNames.size(); s++) {
        if (s > 0) json << ",";
        json << jsonValue(p.serviceDisplayNames[s].displayName);
    }
    json << "]";

    json << "}";
    return json.str();
}

static std::string servicesListToJson(const std::vector<ServiceInfo>& services) {
    std::ostringstream svc;
    svc << "{\"type\":\"services\",\"data\":[";
    for (size_t i = 0; i < services.size(); i++) {
        const auto& s = services[i];
        if (i > 0) svc << ",";
        svc << "{";
        svc << "\"serviceName\":" << jsonValue(s.serviceName) << ",";
        svc << "\"displayName\":" << jsonValue(s.displayName) << ",";
        svc << "\"pid\":" << jsonValue(s.pid) << ",";
        svc << "\"status\":" << jsonValue(s.status) << ",";
        svc << "\"statusCode\":" << jsonValue(s.statusCode) << ",";
        svc << "\"description\":" << jsonValue(s.description) << ",";
        svc << "\"group\":" << jsonValue(s.group) << ",";
        svc << "\"type\":" << jsonValue(s.type);
        svc << "}";
    }
    svc << "]}";
    return svc.str();
}

static void sendServicesPush() {
    auto services = enumerateAllServices();
    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << servicesListToJson(services) << std::endl;
}

// Push thread enumerates processes and stats every 500ms.

static void pushThreadFunc() {
    while (g_running) {
        try {
            auto processes = enumerateProcesses();

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

            SystemStats stats = getSystemStats();
            uint32_t totalProcesses = 0, totalThreads = 0, totalHandles = 0;
            getProcessSystemCounts(totalProcesses, totalThreads, totalHandles);
            double diskReadBps = 0.0, diskWriteBps = 0.0;
            getSystemDiskStats(diskReadBps, diskWriteBps);
            double gpuPercent = gpuGetTotalUsage();

            populateDiskInfo(stats);
            populateNetworkInfo(stats);
            populateGpuInfo(stats);

            static ULONGLONG prevNetSend = 0, prevNetRecv = 0, prevNetTick = 0;
            double netSendBps = 0, netRecvBps = 0;
            {
                auto netSnapshot = g_networkMonitor.snapshot();
                ULONGLONG curSend = 0, curRecv = 0;
                for (const auto& [pid, ns] : netSnapshot) {
                    curSend += ns.sendBytes;
                    curRecv += ns.recvBytes;
                }
                ULONGLONG now = GetTickCount64();
                if (prevNetTick != 0) {
                    ULONGLONG elapsedMs = now - prevNetTick;
                    if (elapsedMs > 0) {
                        netSendBps = (double)(curSend - prevNetSend) * 1000.0 / elapsedMs;
                        netRecvBps = (double)(curRecv - prevNetRecv) * 1000.0 / elapsedMs;
                    }
                }
                prevNetSend = curSend;
                prevNetRecv = curRecv;
                prevNetTick = now;
            }

            {
                std::lock_guard<std::mutex> lock(g_dataMutex);
                g_latestProcesses = processes;
            }

            uint32_t seq = ++g_seqCounter;
            bool isFullSnapshot = (g_prevProcesses.empty() || seq % 4 == 0);

            if (isFullSnapshot) {
                std::string processesJson = processesToJson(processes);
                std::string statsJson = statsToJson(stats, totalProcesses, totalThreads, totalHandles, diskReadBps, diskWriteBps, gpuPercent, netSendBps, netRecvBps);
                auto services = enumerateAllServices();
                std::string servicesJson = servicesListToJson(services);
                {
                    std::lock_guard<std::mutex> lock(g_stdoutMutex);
                    std::cout << "{\"type\":\"processes\",\"data\":" << processesJson << ",\"seq\":" << seq << "}" << std::endl;
                    std::cout << "{\"type\":\"stats\",\"data\":" << statsJson << "}" << std::endl;
                    std::cout << servicesJson << std::endl;
                }
                g_prevProcesses = processes;
            } else {
                std::unordered_map<uint32_t, size_t> prevByPid;
                for (size_t i = 0; i < g_prevProcesses.size(); i++) {
                    prevByPid[g_prevProcesses[i].pid] = i;
                }

                std::unordered_map<uint32_t, uint64_t> curFingerprints;
                std::vector<const ProcessInfo*> added, updated;
                std::vector<uint32_t> removed;

                for (const auto& p : processes) {
                    curFingerprints[p.pid] = processFingerprint(p);
                    auto it = prevByPid.find(p.pid);
                    if (it == prevByPid.end()) {
                        added.push_back(&p);
                    } else {
                        if (processFingerprint(g_prevProcesses[it->second]) != curFingerprints[p.pid]) {
                            updated.push_back(&p);
                        }
                        prevByPid.erase(it);
                    }
                }

                for (const auto& pair : prevByPid) {
                    removed.push_back(pair.first);
                }

                g_prevProcesses = processes;

                std::string statsJson = statsToJson(stats, totalProcesses, totalThreads, totalHandles, diskReadBps, diskWriteBps, gpuPercent, netSendBps, netRecvBps);

                if (added.empty() && updated.empty() && removed.empty()) {
                    {
                        std::lock_guard<std::mutex> lock(g_stdoutMutex);
                        std::cout << "{\"type\":\"stats\",\"data\":" << statsJson << "}" << std::endl;
                    }
                } else {
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

                    {
                        std::lock_guard<std::mutex> lock(g_stdoutMutex);
                        std::cout << diff.str() << std::endl;
                        std::cout << "{\"type\":\"stats\",\"data\":" << statsJson << "}" << std::endl;
                    }
                }
            }
        }
        catch (const std::exception& e) {
            std::lock_guard<std::mutex> lock(g_stdoutMutex);
            std::cerr << "Push thread error: " << e.what() << std::endl;
        }
        catch (...) {
            std::cerr << "Push thread unknown error" << std::endl;
        }

        for (int i = 0; i < 10 && g_running; i++) {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    }
}

// Helpers.

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

// Command handlers.

static void handlePing(const Params& params) {
    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << "{\"type\":\"ack\",\"cmd\":\"ping\",\"success\":true}" << std::endl;
}

static void handleIcon(const Params& params) {
    int pid = getIntParam(params, "pid");
    if (pid == 0) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"get_icon\",\"error\":\"Missing pid\"}" << std::endl;
        return;
    }

    std::string iconBase64 = getProcessIconBase64((uint32_t)pid);
    std::ostringstream json;
    json << "{";
    json << "\"type\":\"icon\",";
    json << "\"pid\":" << pid << ",";
    json << "\"icon\":" << jsonValue(iconBase64);
    json << "}";

    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << json.str() << std::endl;
}

static void handleIconsBatch(const Params& params) {
    auto it = params.find("pids");
    if (it == params.end()) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"get_icons\",\"error\":\"Missing pids\"}" << std::endl;
        return;
    }

    auto pids = parseIntArray(it->second);
    std::ostringstream json;
    json << "{\"type\":\"icons\",\"icons\":[";
    bool first = true;
    for (uint32_t pid : pids) {
        if (!first) json << ",";
        first = false;
        std::string iconBase64 = getProcessIconBase64(pid);
        json << "{\"pid\":" << pid << ",\"icon\":" << jsonValue(iconBase64) << "}";
    }
    json << "]}";

    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << json.str() << std::endl;
}

static void handleTerminate(const Params& params) {
    int pid = getIntParam(params, "pid");
    if (pid == 0) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"terminate\",\"error\":\"Missing pid\"}" << std::endl;
        return;
    }

    if (pid <= 4) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"terminate\",\"pid\":" << pid << ",\"success\":false,\"error\":\"Cannot terminate system process\"}" << std::endl;
        return;
    }

    int hwnd = getIntParam(params, "hwnd");
    if (hwnd != 0) {
        HWND windowHandle = reinterpret_cast<HWND>((uint64_t)hwnd);
        BOOL result = PostMessageW(windowHandle, WM_CLOSE, 0, 0);
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"close_window\",\"hwnd\":" << hwnd << ",\"success\":" << jsonValue(result == TRUE) << "}" << std::endl;
        return;
    }

    bool success = terminateProcess((uint32_t)pid);
    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << "{\"type\":\"ack\",\"cmd\":\"terminate\",\"pid\":" << pid << ",\"success\":" << jsonValue(success) << "}" << std::endl;
}

static void handleTerminateTree(const Params& params) {
    int pid = getIntParam(params, "pid");
    if (pid == 0) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"terminate_tree\",\"error\":\"Missing pid\"}" << std::endl;
        return;
    }

    if (pid <= 4) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"terminate_tree\",\"pid\":" << pid << ",\"success\":false,\"error\":\"Cannot terminate system process\"}" << std::endl;
        return;
    }

    bool success = terminateProcessTree((uint32_t)pid);
    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << "{\"type\":\"ack\",\"cmd\":\"terminate_tree\",\"pid\":" << pid << ",\"success\":" << jsonValue(success) << "}" << std::endl;
}

static void handleTerminateBatch(const Params& params) {
    auto it = params.find("pids");
    if (it == params.end()) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"terminate_batch\",\"success\":false,\"error\":\"Missing pids\"}" << std::endl;
        return;
    }

    auto pids = parseIntArray(it->second);
    int terminated = terminateProcesses(pids);

    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << "{\"type\":\"ack\",\"cmd\":\"terminate_batch\",\"success\":" << jsonValue(terminated > 0)
              << ",\"terminated\":" << terminated << ",\"total\":" << pids.size() << "}" << std::endl;
}

static void handleCheckDangerous(const Params& params) {
    int pid = getIntParam(params, "pid");
    if (pid == 0) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"dangerous\",\"pid\":0,\"dangerous\":false}" << std::endl;
        return;
    }

    bool dangerous = isDangerousProcess((uint32_t)pid);
    std::wstring name = getDangerousProcessName((uint32_t)pid);

    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << "{\"type\":\"dangerous\",\"pid\":" << pid << ",\"dangerous\":" << jsonValue(dangerous)
              << ",\"name\":" << jsonValue(name) << "}" << std::endl;
}

static void handleListServices(const Params& params) {
    auto services = enumerateAllServices();
    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << servicesListToJson(services) << std::endl;
}

static void handleStartService(const Params& params) {
    std::string nameStr = getStrParam(params, "name");
    if (nameStr.empty()) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"start_service\",\"success\":false,\"error\":\"Missing name\"}" << std::endl;
        return;
    }

    std::wstring name = utf8ToWide(nameStr);
    bool success = startServiceByName(name);
    unsigned long err = getLastServiceError();

    std::string errMsg = success ? "" : getErrorMessage(err);
    {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"start_service\",\"name\":" << jsonValue(nameStr)
                  << ",\"success\":" << jsonValue(success) << ",\"errorCode\":" << (int)err
                  << ",\"errorMessage\":" << jsonValue(errMsg) << "}" << std::endl;
    }
    sendServicesPush();
}

static void handleStopService(const Params& params) {
    std::string nameStr = getStrParam(params, "name");
    if (nameStr.empty()) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"stop_service\",\"success\":false,\"error\":\"Missing name\"}" << std::endl;
        return;
    }

    std::wstring name = utf8ToWide(nameStr);
    bool success = stopServiceByName(name);
    unsigned long err = getLastServiceError();
    std::string errMsg = success ? "" : getErrorMessage(err);

    {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"stop_service\",\"name\":" << jsonValue(nameStr)
                  << ",\"success\":" << jsonValue(success) << ",\"errorCode\":" << (int)err
                  << ",\"errorMessage\":" << jsonValue(errMsg) << "}" << std::endl;
    }
    sendServicesPush();
}

static void handleRestartService(const Params& params) {
    std::string nameStr = getStrParam(params, "name");
    if (nameStr.empty()) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"restart_service\",\"success\":false,\"error\":\"Missing name\"}" << std::endl;
        return;
    }

    std::wstring name = utf8ToWide(nameStr);
    bool success = restartServiceByName(name);
    unsigned long err = getLastServiceError();
    std::string errMsg = success ? "" : getErrorMessage(err);

    {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"restart_service\",\"name\":" << jsonValue(nameStr)
                  << ",\"success\":" << jsonValue(success) << ",\"errorCode\":" << (int)err
                  << ",\"errorMessage\":" << jsonValue(errMsg) << "}" << std::endl;
    }
    sendServicesPush();
}

static void handleListUsers(const Params& params) {
    auto processes = enumerateProcesses();

    std::vector<std::wstring> allUsernames;
    for (const auto& p : processes) {
        if (!p.userName.empty()) {
            allUsernames.push_back(p.userName);
        }
    }

    auto realUsers = filterRealUsers(allUsernames);

    std::ostringstream json;
    json << "{\"type\":\"users\",\"data\":[";
    for (size_t i = 0; i < realUsers.size(); i++) {
        if (i > 0) json << ",";
        json << jsonValue(realUsers[i]);
    }
    json << "]}";

    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << json.str() << std::endl;
}

static void handleProperties(const Params& params) {
    int pid = getIntParam(params, "pid");
    if (pid == 0) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"properties\",\"pid\":0,\"success\":false,\"error\":\"Missing pid\"}" << std::endl;
        return;
    }

    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
    if (!hProcess) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"properties\",\"pid\":" << pid << ",\"success\":false,\"error\":\"Cannot open process\"}" << std::endl;
        return;
    }

    WCHAR path[MAX_PATH] = {};
    DWORD pathLen = MAX_PATH;
    BOOL ok = QueryFullProcessImageNameW(hProcess, 0, path, &pathLen);
    CloseHandle(hProcess);
    if (!ok) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"properties\",\"pid\":" << pid << ",\"success\":false,\"error\":\"Cannot get process path\"}" << std::endl;
        return;
    }

    std::wstring wpath(path);
    std::string narrowPath = narrowWide(wpath);
    std::string escapedPath;
    for (char c : narrowPath) {
        if (c == '\\') escapedPath += "\\\\";
        else if (c == '"') escapedPath += "\\\"";
        else escapedPath += c;
    }

    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"properties\",\"pid\":" << pid << ",\"success\":false,\"error\":\"COM init failed\",\"path\":\"" + escapedPath + "\"}" << std::endl;
        return;
    }

    SHELLEXECUTEINFOW sei = {0};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_INVOKEIDLIST;
    sei.lpVerb = L"properties";
    sei.lpFile = wpath.c_str();
    sei.nShow = SW_SHOW;

    BOOL result = ShellExecuteExW(&sei);

    if (hr == S_OK) CoUninitialize();

    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << "{\"type\":\"properties\",\"pid\":" << pid << ",\"success\":" << jsonValue(result == TRUE) << ",\"path\":\"" + escapedPath + "\"}" << std::endl;
}

static void handleOpenServices(const Params& params) {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"open_services\",\"success\":false,\"error\":\"COM init failed\"}" << std::endl;
        return;
    }

    SHELLEXECUTEINFOW sei = {0};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOASYNC;
    sei.lpVerb = L"open";
    sei.lpFile = L"services.msc";
    sei.nShow = SW_SHOW;

    BOOL result = ShellExecuteExW(&sei);

    if (hr == S_OK) CoUninitialize();

    std::lock_guard<std::mutex> lock(g_stdoutMutex);
    std::cout << "{\"type\":\"ack\",\"cmd\":\"open_services\",\"success\":" << jsonValue(result == TRUE) << "}" << std::endl;
}

static void handleShutdown(const Params& params) {
    {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":\"shutdown\",\"success\":true}" << std::endl;
    }
    g_running = false;
}

// Command dispatch.

using HandlerFunc = void (*)(const Params&);
static const std::unordered_map<std::string, HandlerFunc> g_handlers = {
    {"ping", handlePing},
    {"get_icon", handleIcon},
    {"get_icons", handleIconsBatch},
    {"terminate", handleTerminate},
    {"close_window", handleTerminate},
    {"terminate_tree", handleTerminateTree},
    {"terminate_batch", handleTerminateBatch},
    {"check_dangerous", handleCheckDangerous},
    {"list_services", handleListServices},
    {"start_service", handleStartService},
    {"stop_service", handleStopService},
    {"restart_service", handleRestartService},
    {"list_users", handleListUsers},
    {"properties", handleProperties},
    {"open_services", handleOpenServices},
    {"shutdown", handleShutdown},
};

static void dispatchCommand(const std::string& line) {
    std::string trimmed = trim(line);
    if (trimmed.empty()) return;

    Params params = parseJsonObject(trimmed);
    std::string cmd = getStrParam(params, "cmd");

    if (cmd.empty()) {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"error\":\"Missing 'cmd' field in JSON\"}" << std::endl;
        return;
    }

    auto it = g_handlers.find(cmd);
    if (it != g_handlers.end()) {
        it->second(params);
    } else {
        std::lock_guard<std::mutex> lock(g_stdoutMutex);
        std::cout << "{\"type\":\"ack\",\"cmd\":" << jsonValue(cmd) << ",\"error\":\"Unknown command\"}" << std::endl;
    }
}

// Main.

int main() {
    // Init progress goes to stderr so stdout stays clean for JSON output.
    std::cerr << "SysPie Native v1.0.0" << std::endl;

    if (!ntApiInit()) {
        std::cerr << "ERROR: Failed to initialize NT API functions." << std::endl;
        std::cerr << "This application must run on Windows with ntdll.dll." << std::endl;
        return 1;
    }
    std::cerr << "NT API initialized." << std::endl;

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

    if (g_networkMonitor.start()) {
        std::cerr << "Network ETW monitor started." << std::endl;
    } else {
        std::cerr << "Network ETW monitor: not available." << std::endl;
    }

    if (!iconCacheInit()) {
        std::cerr << "WARNING: Failed to initialize icon cache." << std::endl;
    }
    std::cerr << "Icon cache initialized." << std::endl;

    if (!gpuInit()) {
        std::cerr << "GPU monitoring: Not available (requires Win10 RS4+ with WDDM 2.0+)." << std::endl;
    } else {
        std::cerr << "GPU monitoring initialized." << std::endl;
    }

    if (!gpuEngineInit()) {
        std::cerr << "GPU Engine names: Not available (PDH counters not found)." << std::endl;
    } else {
        gpuEngineStartCollector();
        std::cerr << "GPU Engine names initialized." << std::endl;
    }

    // Start push thread
    std::thread pushThread(pushThreadFunc);
    pushThread.detach();

    std::cerr << "Native library ready. Listening on stdin for JSON commands..." << std::endl;

    // Stdin command loop
    std::string line;
    while (g_running && std::getline(std::cin, line)) {
        dispatchCommand(line);
    }

    // Cleanup
    g_running = false;
    g_networkMonitor.stop();
    iconCacheShutdown();

    std::cerr << "Native library stopped." << std::endl;
    return 0;
}
