#pragma once

// Shared data structures used by all native modules.

#include <string>
#include <vector>
#include <cstdint>

// One service host process that a service runs under.

struct ServiceHostInfo {
    uint32_t pid = 0;
    std::wstring displayName;
};

// Details about one Windows service, mostly shown on the Services screen. It carries the internal name, the friendly name, the owning process ID, the current state, the description, the service group, and the service type.
struct ServiceInfo {
    std::wstring serviceName;
    std::wstring displayName;
    uint32_t pid = 0;
    std::wstring status;
    uint32_t statusCode = 0;
    std::wstring description;
    std::wstring group;
    std::wstring type;
};

// One visible top level window owned by a process.

struct WindowGroupEntry {
    uint32_t pid = 0;
    uint64_t hwnd = 0;
    std::wstring title;
};

// Everything the UI needs to describe one running process. It holds identity fields like the PID and parent PID, the name and path, user facing detail names, CPU and memory usage in various units, disk and network rates, GPU figures, flags for how the process is categorized, and any child processes, windows, and services it hosts.
struct ProcessInfo {
    uint32_t pid = 0;
    uint32_t parentPid = 0;
    std::wstring name;
    std::wstring aumid;
    std::wstring exePath;
    std::wstring friendlyName;
    std::wstring detailName;
    std::wstring userName;
    std::wstring status;
    int32_t statusType = 0;
    int32_t basePriority = 0;
    uint32_t threadCount = 0;
    uint32_t handleCount = 0;
    uint32_t sessionId = 0;
    long long createTime = 0;
    double cpuUsage = 0.0;
    double memoryBytes = 0.0;
    double memoryMB = 0.0;
    double virtualMemoryMB = 0.0;
    double workingSetMB = 0.0;
    bool memoryAccessDenied = false;
    double diskReadMB = 0.0;
    double diskWriteMB = 0.0;
    uint32_t networkConnections = 0;
    double networkBps = 0.0;
    double gpuPercent = 0.0;
    std::wstring gpuEngine;
    std::wstring powerUsage;
    std::wstring diskPermission;
    std::wstring uacVirtualization = L"Disabled";
    bool isWow64 = false;
    bool isProtected = false;
    bool isSuspended = false;
    bool isElevated = false;
    bool isBackground = false;
    bool isSystemProcess = false;
    bool hasVisibleWindow = false;
    bool hasIdeMatch = false;
    bool hasChildren = false;
    uint32_t childCount = 0;
    std::vector<ProcessInfo> children;
    std::vector<WindowGroupEntry> windowTitles;
    std::vector<ServiceHostInfo> serviceDisplayNames;
};

// Running totals and hardware details shown on the system statistics screens.

struct SystemStats {
    // CPU
    double cpuUsagePercent = 0.0;
    double cpuKernelPercent = 0.0;
    double cpuUserPercent = 0.0;
    uint32_t totalProcesses = 0;
    uint32_t totalThreads = 0;
    uint32_t totalHandles = 0;

    // CPU info
    std::wstring cpuName;
    double cpuSpeedMHz = 0.0;
    double cpuBaseSpeedMHz = 0.0;
    uint32_t cpuSockets = 0;
    uint32_t cpuCores = 0;
    uint32_t cpuLogicalProcessors = 0;
    bool cpuVirtualization = false;
    uint64_t cpuL1CacheKB = 0;
    uint64_t cpuL2CacheKB = 0;
    uint64_t cpuL3CacheKB = 0;
    uint64_t uptimeSeconds = 0;

    // Memory
    double totalPhysicalMB = 0.0;
    double usedPhysicalMB = 0.0;
    double availablePhysicalMB = 0.0;
    double commitChargeMB = 0.0;
    double commitLimitMB = 0.0;

    // Memory info
    double memoryCompressedMB = 0.0;
    double memoryCachedMB = 0.0;
    double memoryPagedPoolMB = 0.0;
    double memoryNonPagedPoolMB = 0.0;
    uint32_t memorySpeedMHz = 0;
    uint32_t memorySlotsUsed = 0;
    uint32_t memorySlotsTotal = 0;
    std::wstring memoryFormFactor;
    std::wstring memoryType;
    double memoryHardwareReservedMB = 0.0;

    // I/O
    double diskReadBytesPerSec = 0.0;
    double diskWriteBytesPerSec = 0.0;

    // Disk info
    double diskActivePercent = 0.0;
    double diskAvgResponseMs = 0.0;
    uint64_t diskCapacityBytes = 0;
    bool diskIsSystem = false;
    bool diskHasPageFile = false;
    std::wstring diskType;
    std::wstring diskModel;

    // Network info
    std::wstring netAdapterName;
    std::wstring netNicModel;
    std::wstring netSsid;
    std::wstring netConnectionType;
    std::wstring netIpv4Address;
    std::wstring netIpv6Address;
    uint32_t netSignalPercent = 0;

    // GPU info
    double gpuDedicatedMB = 0.0;
    double gpuSharedMB = 0.0;
    double gpuTotalMemoryMB = 0.0;
    double gpuDedicatedTotalMB = 0.0;
    double gpuSharedTotalMB = 0.0;
    std::wstring gpuName;
    std::wstring gpuDriverVersion;
    std::wstring gpuDriverDate;
    std::wstring gpuDirectXVersion;
    std::wstring gpuPhysicalLocation;
    double gpuHardwareReservedMB = 0.0;
};
