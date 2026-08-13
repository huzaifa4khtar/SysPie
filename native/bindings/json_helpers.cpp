#include "json_helpers.h"
#include <sstream>
#include <iomanip>
#include <windows.h>

std::string escapeJsonString(const std::wstring& wstr) {
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

std::string jsonValue(double val) {
    std::ostringstream ss;
    ss << std::fixed << std::setprecision(1) << val;
    return ss.str();
}

std::string jsonValue(int val) {
    return std::to_string(val);
}

std::string jsonValue(unsigned int val) {
    return std::to_string(val);
}

std::string jsonValue(uint64_t val) {
    return std::to_string(val);
}

std::string jsonValue(bool val) {
    return val ? "true" : "false";
}

std::string jsonValue(const std::string& val) {
    return "\"" + val + "\"";
}

std::string jsonValue(const std::wstring& val) {
    if (val.empty()) return "\"\"";
    return "\"" + escapeJsonString(val) + "\"";
}

std::string narrowWide(const std::wstring& ws) {
    if (ws.empty()) return "";
    int len = WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), nullptr, 0, nullptr, nullptr);
    if (len <= 0) return "";
    std::string result(len, '\0');
    WideCharToMultiByte(CP_UTF8, 0, ws.c_str(), (int)ws.size(), &result[0], len, nullptr, nullptr);
    return result;
}

std::string processesToJson(const std::vector<ProcessInfo>& processes) {
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

std::string statsToJson(const SystemStats& stats, uint32_t totalProcesses, uint32_t totalThreads,
                        uint32_t totalHandles, double diskReadBps, double diskWriteBps, double gpuPercent,
                        double netSendBps, double netRecvBps) {
    std::ostringstream json;
    json << "{";
    // CPU usage
    json << "\"cpuUsagePercent\":" << jsonValue(stats.cpuUsagePercent) << ",";
    json << "\"cpuKernelPercent\":" << jsonValue(stats.cpuKernelPercent) << ",";
    json << "\"cpuUserPercent\":" << jsonValue(stats.cpuUserPercent) << ",";
    // Process counts
    json << "\"totalProcesses\":" << jsonValue(totalProcesses) << ",";
    json << "\"totalThreads\":" << jsonValue(totalThreads) << ",";
    json << "\"totalHandles\":" << jsonValue(totalHandles) << ",";
    // Memory
    json << "\"totalPhysicalMB\":" << jsonValue(stats.totalPhysicalMB) << ",";
    json << "\"usedPhysicalMB\":" << jsonValue(stats.usedPhysicalMB) << ",";
    json << "\"availablePhysicalMB\":" << jsonValue(stats.availablePhysicalMB) << ",";
    json << "\"commitChargeMB\":" << jsonValue(stats.commitChargeMB) << ",";
    json << "\"commitLimitMB\":" << jsonValue(stats.commitLimitMB) << ",";
    // Disk I/O rates
    json << "\"diskReadMBps\":" << jsonValue(diskReadBps) << ",";
    json << "\"diskWriteMBps\":" << jsonValue(diskWriteBps) << ",";
    // GPU
    json << "\"gpuUsagePercent\":" << jsonValue(gpuPercent) << ",";
    // Network rates
    json << "\"netSendBps\":" << jsonValue(netSendBps) << ",";
    json << "\"netRecvBps\":" << jsonValue(netRecvBps) << ",";
    // CPU info
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
    // Memory info
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
    // Disk info
    json << "\"diskActivePercent\":" << jsonValue(stats.diskActivePercent) << ",";
    json << "\"diskAvgResponseMs\":" << jsonValue(stats.diskAvgResponseMs) << ",";
    json << "\"diskCapacityBytes\":" << jsonValue(stats.diskCapacityBytes) << ",";
    json << "\"diskIsSystem\":" << jsonValue(stats.diskIsSystem) << ",";
    json << "\"diskHasPageFile\":" << jsonValue(stats.diskHasPageFile) << ",";
    json << "\"diskType\":" << jsonValue(stats.diskType) << ",";
    json << "\"diskModel\":" << jsonValue(stats.diskModel) << ",";
    // Network info
    json << "\"netAdapterName\":" << jsonValue(stats.netAdapterName) << ",";
    json << "\"netNicModel\":" << jsonValue(stats.netNicModel) << ",";
    json << "\"netSsid\":" << jsonValue(stats.netSsid) << ",";
    json << "\"netConnectionType\":" << jsonValue(stats.netConnectionType) << ",";
    json << "\"netIpv4Address\":" << jsonValue(stats.netIpv4Address) << ",";
    json << "\"netIpv6Address\":" << jsonValue(stats.netIpv6Address) << ",";
    json << "\"netSignalPercent\":" << jsonValue(stats.netSignalPercent) << ",";
    // GPU info
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

std::string processToJson(const ProcessInfo& p) {
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

std::string servicesListToJson(const std::vector<ServiceInfo>& services) {
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
