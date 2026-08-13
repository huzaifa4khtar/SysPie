#include "gpu/gpu_engine_collector.h"
#include <windows.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <vector>
#include <string>
#include <mutex>
#include <unordered_map>
#include <thread>
#include <algorithm>
#include <cstdlib>
#include <cwchar>
#include <new>

#pragma comment(lib, "pdh.lib")

// Internal state

struct EngineEntry {
    std::wstring engineName;
    double utilization;
};

static PDH_HQUERY g_query = NULL;
static PDH_HCOUNTER g_counter = NULL;
static bool g_initialized = false;

static std::mutex g_mutex;
static std::unordered_map<uint32_t, std::vector<EngineEntry>> g_pidEngines;
static std::thread g_collectorThread;

// Instance name parsing. This extracts the pid, gpu index, and engine type from PDH instance
// names of the form pid value luid values phys value eng value engtype value.

static bool parseInstanceName(
    const std::wstring& instanceName,
    uint32_t& outPid,
    int& outGpuIndex,
    std::wstring& outEngineType)
{
    if (instanceName.rfind(L"pid_", 0) != 0) return false;

    size_t pidEnd = instanceName.find(L'_', 4);
    if (pidEnd == std::wstring::npos) return false;

    outPid = (uint32_t)wcstol(instanceName.substr(4, pidEnd - 4).c_str(), nullptr, 10);
    if (outPid == 0) return false;

    size_t physPos = instanceName.find(L"_phys_");
    if (physPos == std::wstring::npos) return false;

    size_t physValStart = physPos + 6;
    size_t physValEnd = instanceName.find(L'_', physValStart);
    if (physValEnd == std::wstring::npos) return false;

    outGpuIndex = (int)wcstol(instanceName.substr(physValStart, physValEnd - physValStart).c_str(), nullptr, 10);

    size_t engtypePos = instanceName.find(L"_engtype_");
    if (engtypePos == std::wstring::npos) return false;

    outEngineType = instanceName.substr(engtypePos + 9);
    return true;
}

static std::wstring engineTypeToDisplayName(const std::wstring& engtype) {
    if (engtype == L"3D") return L"3D";
    if (engtype == L"Copy") return L"Copy";
    if (engtype == L"VideoDecode") return L"Video Decode";
    if (engtype == L"VideoEncode") return L"Video Encode";
    if (engtype == L"VideoProcessing") return L"Video Processing";
    if (engtype == L"Compute") return L"Compute";
    if (engtype == L"Misc") return L"Misc";
    if (engtype == L"LegacyOverlay") return L"Legacy Overlay";
    if (engtype == L"GDI Render") return L"GDI Render";
    if (engtype.empty()) return L"Engine";
    return engtype;
}

// Data collection

static void collectAndRead() {
    if (!g_counter || !g_query) return;

    PdhCollectQueryData(g_query);

    DWORD bufferSize = 0;
    DWORD itemCount = 0;
    PDH_STATUS status = PdhGetFormattedCounterArrayW(g_counter, PDH_FMT_DOUBLE,
        &bufferSize, &itemCount, NULL);

    if (status != PDH_MORE_DATA || bufferSize == 0 || itemCount == 0) return;

    // Allocate a raw byte buffer, since bufferSize includes both structs and string data
    BYTE* buffer = new (std::nothrow) BYTE[bufferSize];
    if (!buffer) return;

    status = PdhGetFormattedCounterArrayW(g_counter, PDH_FMT_DOUBLE,
        &bufferSize, &itemCount, reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buffer));

    if (status != ERROR_SUCCESS) {
        delete[] buffer;
        return;
    }

    PDH_FMT_COUNTERVALUE_ITEM_W* items =
        reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buffer);

    std::unordered_map<uint32_t, std::vector<EngineEntry>> newMap;

    for (DWORD i = 0; i < itemCount; i++) {
        double util = items[i].FmtValue.doubleValue;

        std::wstring instanceName = items[i].szName;
        uint32_t pid = 0;
        int gpuIndex = 0;
        std::wstring engineType;

        if (!parseInstanceName(instanceName, pid, gpuIndex, engineType)) continue;

        std::wstring displayName = L"GPU " + std::to_wstring(gpuIndex)
            + L" - " + engineTypeToDisplayName(engineType);

        newMap[pid].push_back({displayName, util});
    }

    for (auto& [pid, engines] : newMap) {
        std::sort(engines.begin(), engines.end(),
            [](const EngineEntry& a, const EngineEntry& b) {
                return a.utilization > b.utilization;
            });
    }

    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_pidEngines = std::move(newMap);
    }

    delete[] buffer;
}

// Background thread

static void collectorThreadFunc() {
    while (true) {
        Sleep(1000);
        collectAndRead();
    }
}

// Public API

bool gpuEngineInit() {
    if (g_initialized) return true;
    g_initialized = true;

    PDH_STATUS status = PdhOpenQueryW(NULL, 0, &g_query);
    if (status != ERROR_SUCCESS) return false;

    status = PdhAddEnglishCounterW(g_query,
        L"\\GPU Engine(*)\\Utilization Percentage", 0, &g_counter);
    if (status != ERROR_SUCCESS) {
        PdhCloseQuery(g_query);
        g_query = NULL;
        g_counter = NULL;
        return false;
    }

    PdhCollectQueryData(g_query);
    Sleep(1000);
    PdhCollectQueryData(g_query);

    return true;
}

void gpuEngineStartCollector() {
    if (!g_initialized) return;
    g_collectorThread = std::thread(collectorThreadFunc);
    g_collectorThread.detach();
}

std::wstring gpuEngineGetPrimaryEngine(uint32_t pid) {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_pidEngines.find(pid);
    if (it == g_pidEngines.end() || it->second.empty()) {
        return L"";
    }
    return it->second.front().engineName;
}
