#include "gpu/gpu_stats.h"
#define INITGUID
#include <windows.h>
#include <dxgi.h>
#include <d3dkmthk.h>
#include <d3d11.h>
#include <setupapi.h>
#include <devpkey.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <vector>
#include <mutex>
#include <unordered_map>

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "setupapi.lib")
#pragma comment(lib, "pdh.lib")

// D3DKMT function pointers, loaded dynamically from gdi32.dll

typedef LONG NTSTATUS;

typedef NTSTATUS(APIENTRY* pfnD3DKMTOpenAdapterFromLuid)(const D3DKMT_OPENADAPTERFROMLUID*);
typedef NTSTATUS(APIENTRY* pfnD3DKMTQueryStatistics)(D3DKMT_QUERYSTATISTICS*);
typedef NTSTATUS(APIENTRY* pfnD3DKMTQueryAdapterInfo)(D3DKMT_QUERYADAPTERINFO*);

static pfnD3DKMTOpenAdapterFromLuid pOpenAdapterFromLuid = NULL;
static pfnD3DKMTQueryStatistics pQueryStatistics = NULL;
static pfnD3DKMTQueryAdapterInfo pQueryAdapterInfo = NULL;
static bool g_gpuAvailable = false;
static bool g_gpuInitialized = false;

// Adapter tracking

struct GpuAdapterInfo {
    LUID adapterLuid;
    ULONG nodeCount;
};

struct GpuFullAdapterInfo {
    LUID adapterLuid;
    ULONG nodeCount;
    DXGI_ADAPTER_DESC desc;
    IDXGIAdapter* dxgiAdapter;
};

static std::vector<GpuAdapterInfo> g_adapters;
static std::vector<GpuFullAdapterInfo> g_fullAdapters;
static std::mutex g_gpuMutex;

// D3DKMT adapter handle and segment size info
static D3DKMT_HANDLE g_adapterHandle = 0;
static D3DKMT_SEGMENTSIZEINFO g_segmentSizeInfo = {};
static bool g_segmentInfoValid = false;

// Segment count and aperture bitmap for memory usage queries
static ULONG g_segmentCount = 0;
static bool g_apertureSegments[64] = {};

// PDH counters for GPU memory usage, matching Task Manager. They read Dedicated Usage and Shared Usage.
static PDH_HQUERY g_gpuMemQuery = NULL;
static PDH_HCOUNTER g_gpuDedicatedCounter = NULL;
static PDH_HCOUNTER g_gpuSharedCounter = NULL;
static bool g_gpuMemPdhReady = false;

// Per process GPU running time tracking
struct GpuProcessTime {
    ULONGLONG prevRunningTime;
};
static std::unordered_map<uint32_t, GpuProcessTime> g_gpuProcessTimes;

// Total GPU tracking
static ULONGLONG g_prevGlobalRunningTime = 0;
static ULONGLONG g_prevClockTicks = 0;
static ULONGLONG g_prevTotalClockTicks = 0;
static LARGE_INTEGER g_perfFrequency = {};

// DXGI adapter enumeration

static bool enumerateAdaptersDXGI() {
    IDXGIFactory* pFactory = nullptr;
    HRESULT hr = CreateDXGIFactory(__uuidof(IDXGIFactory), (void**)&pFactory);
    if (FAILED(hr) || !pFactory) return false;

    IDXGIAdapter* pAdapter = nullptr;
    for (UINT i = 0; pFactory->EnumAdapters(i, &pAdapter) != DXGI_ERROR_NOT_FOUND; i++) {
        DXGI_ADAPTER_DESC desc = {};
        hr = pAdapter->GetDesc(&desc);
        if (SUCCEEDED(hr)) {
            // Query node count via D3DKMTQueryStatistics
            D3DKMT_QUERYSTATISTICS query = {};
            query.Type = D3DKMT_QUERYSTATISTICS_ADAPTER;
            query.AdapterLuid = desc.AdapterLuid;

            NTSTATUS status = pQueryStatistics(&query);
            ULONG nodeCount = 1;
            if (status >= 0) {
                nodeCount = query.QueryResult.AdapterInformation.NodeCount;
                if (nodeCount == 0) nodeCount = 1;
            }

            GpuAdapterInfo info;
            info.adapterLuid = desc.AdapterLuid;
            info.nodeCount = nodeCount;
            g_adapters.push_back(info);

            GpuFullAdapterInfo fullInfo;
            fullInfo.adapterLuid = desc.AdapterLuid;
            fullInfo.nodeCount = nodeCount;
            fullInfo.desc = desc;
            fullInfo.dxgiAdapter = pAdapter;
            pAdapter->AddRef();  // Hold reference for D3D11 feature level probe
            g_fullAdapters.push_back(fullInfo);
        }
        pAdapter->Release();
    }

    pFactory->Release();
    return !g_adapters.empty();
}

// Public API

bool gpuInit() {
    if (g_gpuInitialized) return g_gpuAvailable;
    g_gpuInitialized = true;

    HMODULE hGdi32 = LoadLibraryW(L"gdi32.dll");
    if (!hGdi32) return false;

    pOpenAdapterFromLuid = (pfnD3DKMTOpenAdapterFromLuid)
        GetProcAddress(hGdi32, "D3DKMTOpenAdapterFromLuid");
    pQueryStatistics = (pfnD3DKMTQueryStatistics)
        GetProcAddress(hGdi32, "D3DKMTQueryStatistics");
    pQueryAdapterInfo = (pfnD3DKMTQueryAdapterInfo)
        GetProcAddress(hGdi32, "D3DKMTQueryAdapterInfo");

    if (!pOpenAdapterFromLuid || !pQueryStatistics || !pQueryAdapterInfo) {
        return false;
    }

    // Get performance counter frequency for timing
    QueryPerformanceFrequency(&g_perfFrequency);

    // Enumerate adapters via DXGI
    g_gpuAvailable = enumerateAdaptersDXGI();

    // Open the adapter handle and query segment sizes and segment count for memory info
    if (g_gpuAvailable && !g_fullAdapters.empty()) {
        // Find the adapter with the most dedicated video memory (the discrete GPU)
        size_t bestIdx = 0;
        for (size_t i = 1; i < g_fullAdapters.size(); i++) {
            if (g_fullAdapters[i].desc.DedicatedVideoMemory > g_fullAdapters[bestIdx].desc.DedicatedVideoMemory) {
                bestIdx = i;
            }
        }

        D3DKMT_OPENADAPTERFROMLUID openAdapter = {};
        openAdapter.AdapterLuid = g_fullAdapters[bestIdx].adapterLuid;
        NTSTATUS status = pOpenAdapterFromLuid(&openAdapter);
        if (status == 0) {
            g_adapterHandle = openAdapter.hAdapter;

            D3DKMT_QUERYADAPTERINFO queryAdapter = {};
            queryAdapter.hAdapter = g_adapterHandle;
            queryAdapter.Type = KMTQAITYPE_GETSEGMENTSIZE;
            D3DKMT_SEGMENTSIZEINFO segInfo = {};
            queryAdapter.pPrivateDriverData = &segInfo;
            queryAdapter.PrivateDriverDataSize = sizeof(segInfo);
            status = pQueryAdapterInfo(&queryAdapter);
            if (status == 0) {
                g_segmentSizeInfo = segInfo;
                g_segmentInfoValid = true;
            }

            // Query adapter info to get segment count
            D3DKMT_QUERYSTATISTICS queryStats = {};
            queryStats.Type = D3DKMT_QUERYSTATISTICS_ADAPTER;
            queryStats.AdapterLuid = g_fullAdapters[bestIdx].adapterLuid;
            status = pQueryStatistics(&queryStats);
            if (status >= 0) {
                g_segmentCount = queryStats.QueryResult.AdapterInformation.NbSegments;

                // Query each segment to see which are aperture, meaning shared, versus non aperture, meaning dedicated
                for (ULONG s = 0; s < g_segmentCount && s < 64; s++) {
                    D3DKMT_QUERYSTATISTICS segQuery = {};
                    segQuery.Type = D3DKMT_QUERYSTATISTICS_SEGMENT;
                    segQuery.AdapterLuid = g_fullAdapters[bestIdx].adapterLuid;
                    segQuery.QuerySegment.SegmentId = s;
                    NTSTATUS segStatus = pQueryStatistics(&segQuery);
                    if (segStatus >= 0) {
                        g_apertureSegments[s] = (segQuery.QueryResult.SegmentInformation.Aperture != 0);
                    }
                }
            }
        }
    }

    if (g_gpuAvailable) {
        PDH_STATUS pdhStatus = PdhOpenQueryW(NULL, 0, &g_gpuMemQuery);
        if (pdhStatus == ERROR_SUCCESS) {
            PdhAddEnglishCounterW(g_gpuMemQuery,
                L"\\GPU Adapter Memory(*)\\Dedicated Usage", 0, &g_gpuDedicatedCounter);
            PdhAddEnglishCounterW(g_gpuMemQuery,
                L"\\GPU Adapter Memory(*)\\Shared Usage", 0, &g_gpuSharedCounter);

            if (g_gpuDedicatedCounter && g_gpuSharedCounter) {
                // Prime the counters with two samples (first sample is always 0)
                PdhCollectQueryData(g_gpuMemQuery);
                Sleep(500);
                PdhCollectQueryData(g_gpuMemQuery);
                g_gpuMemPdhReady = true;
            }
        }
    }

    return g_gpuAvailable;
}

// Returns elapsed time in 100ns units since the last call. Call once per refresh cycle before the per process GPU loop.
ULONGLONG gpuGetElapsed100ns() {
    LARGE_INTEGER counter = {};
    QueryPerformanceCounter(&counter);

    ULONGLONG currentTicks = (ULONGLONG)counter.QuadPart;
    ULONGLONG delta = currentTicks - g_prevClockTicks;
    g_prevClockTicks = currentTicks;

    // Convert performance counter ticks to 100ns units
    if (g_perfFrequency.QuadPart == 0) return 10000000; // 1 second fallback
    return (delta * 10000000ULL) / (ULONGLONG)g_perfFrequency.QuadPart;
}

// Per process GPU usage with an externally provided elapsed time
double gpuGetProcessUsageWithElapsed(uint32_t pid, ULONGLONG elapsed100ns) {
    if (!g_gpuAvailable || elapsed100ns == 0) return 0.0;

    std::lock_guard<std::mutex> lock(g_gpuMutex);

    HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
    if (!hProcess) hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProcess) return 0.0;

    ULONGLONG totalRunningTime = 0;

    for (const auto& adapter : g_adapters) {
        D3DKMT_QUERYSTATISTICS query = {};
        query.Type = D3DKMT_QUERYSTATISTICS_PROCESS_NODE;
        query.AdapterLuid = adapter.adapterLuid;
        query.hProcess = hProcess;
        query.QueryProcessNode.NodeId = 0;

        NTSTATUS status = pQueryStatistics(&query);
        if (status >= 0) {
            totalRunningTime += query.QueryResult.ProcessNodeInformation.RunningTime.QuadPart;
        }
    }

    CloseHandle(hProcess);

    auto& gpuTime = g_gpuProcessTimes[pid];
    ULONGLONG delta = totalRunningTime - gpuTime.prevRunningTime;
    gpuTime.prevRunningTime = totalRunningTime;

    double percent = (double)delta / (double)elapsed100ns * 100.0;
    if (percent > 100.0) percent = 100.0;
    if (percent < 0.0) percent = 0.0;
    return percent;
}

double gpuGetTotalUsage() {
    if (!g_gpuAvailable) return 0.0;

    std::lock_guard<std::mutex> lock(g_gpuMutex);

    ULONGLONG totalGlobalRunningTime = 0;

    for (const auto& adapter : g_adapters) {
        D3DKMT_QUERYSTATISTICS query = {};
        query.Type = D3DKMT_QUERYSTATISTICS_NODE;
        query.AdapterLuid = adapter.adapterLuid;
        query.QueryNode.NodeId = 0;

        NTSTATUS status = pQueryStatistics(&query);
        if (status >= 0) {
            totalGlobalRunningTime += query.QueryResult.NodeInformation.GlobalInformation.RunningTime.QuadPart;
        }
    }

    ULONGLONG globalDelta = totalGlobalRunningTime - g_prevGlobalRunningTime;
    g_prevGlobalRunningTime = totalGlobalRunningTime;

    if (g_prevTotalClockTicks == 0) {
        g_prevTotalClockTicks = g_prevClockTicks;
        return 0.0;
    }

    LARGE_INTEGER counter = {};
    QueryPerformanceCounter(&counter);
    ULONGLONG currentTicks = (ULONGLONG)counter.QuadPart;
    ULONGLONG elapsed100ns = ((currentTicks - g_prevTotalClockTicks) * 10000000ULL) / (ULONGLONG)g_perfFrequency.QuadPart;
    g_prevTotalClockTicks = currentTicks;

    double percent = (double)globalDelta / (double)elapsed100ns * 100.0;
    if (percent > 100.0) percent = 100.0;
    if (percent < 0.0) percent = 0.0;
    return percent;
}

// GPU info population

// GUID for display devices
static const GUID GUID_DISPLAY_DEVICE_ARRIVAL = { 0x4d36e968, 0xe325, 0x11ce, { 0xbf, 0xc1, 0x08, 0x00, 0x2b, 0xe1, 0x03, 0x18 } };

static bool MatchDisplayDeviceToAdapter(SP_DEVINFO_DATA& devInfoData, HDEVINFO devInfo, USHORT vendorId, USHORT deviceId) {
    WCHAR hardwareId[512] = {};
    if (!SetupDiGetDeviceRegistryPropertyW(devInfo, &devInfoData, SPDRP_HARDWAREID, nullptr,
        (PBYTE)hardwareId, sizeof(hardwareId), nullptr))
        return false;

    wchar_t vendorStr[8], devStr[8];
    swprintf(vendorStr, 8, L"VEN_%04X", vendorId);
    swprintf(devStr, 8, L"DEV_%04X", deviceId);

    bool match = (wcsstr(hardwareId, vendorStr) != nullptr && wcsstr(hardwareId, devStr) != nullptr);
    return match;
}

static std::wstring GetDriverInfoFromRegistry(SP_DEVINFO_DATA& devInfoData, HDEVINFO devInfo, const wchar_t* valueName);

static std::wstring GetDriverInfoFromRegistry(SP_DEVINFO_DATA& devInfoData, HDEVINFO devInfo, const wchar_t* valueName) {
    HKEY hKey = SetupDiOpenDevRegKey(devInfo, &devInfoData, DICS_FLAG_GLOBAL, 0, DIREG_DRV, KEY_READ);
    if (hKey == INVALID_HANDLE_VALUE) return L"";

    DWORD dataType = 0;
    DWORD dataSize = 0;
    LONG result = RegQueryValueExW(hKey, valueName, nullptr, &dataType, nullptr, &dataSize);
    if (result != ERROR_SUCCESS || (dataType != REG_SZ && dataType != REG_DWORD)) {
        RegCloseKey(hKey);
        return L"";
    }

    if (dataType == REG_SZ) {
        std::wstring value(dataSize / sizeof(WCHAR), L'\0');
        result = RegQueryValueExW(hKey, valueName, nullptr, nullptr, (LPBYTE)&value[0], &dataSize);
        RegCloseKey(hKey);
        if (result != ERROR_SUCCESS) return L"";
        while (!value.empty() && value.back() == L'\0') value.pop_back();
        return value;
    } else if (dataType == REG_DWORD) {
        DWORD value = 0;
        RegQueryValueExW(hKey, valueName, nullptr, nullptr, (LPBYTE)&value, &dataSize);
        RegCloseKey(hKey);
        wchar_t buf[32];
        swprintf(buf, 32, L"%u", value);
        return buf;
    }
    RegCloseKey(hKey);
    return L"";
}

static std::wstring GetDeviceDriverVersion(USHORT vendorId, USHORT deviceId) {
    HDEVINFO devInfo = SetupDiGetClassDevsW(
        &GUID_DISPLAY_DEVICE_ARRIVAL, nullptr, nullptr,
        DIGCF_PRESENT);
    if (devInfo == INVALID_HANDLE_VALUE) return L"";

    SP_DEVINFO_DATA devInfoData = {};
    devInfoData.cbSize = sizeof(devInfoData);

    for (DWORD i = 0; SetupDiEnumDeviceInfo(devInfo, i, &devInfoData); i++) {
        if (!MatchDisplayDeviceToAdapter(devInfoData, devInfo, vendorId, deviceId))
            continue;

        // Try DEVPKEY first
        WCHAR driverVersion[256] = {};
        if (SetupDiGetDevicePropertyW(devInfo, &devInfoData,
            &DEVPKEY_Device_DriverVersion, nullptr,
            (PBYTE)driverVersion, sizeof(driverVersion), nullptr, 0) && wcslen(driverVersion) > 0) {
            SetupDiDestroyDeviceInfoList(devInfo);
            return driverVersion;
        }

        // Fallback to reading from the driver registry key
        std::wstring regVersion = GetDriverInfoFromRegistry(devInfoData, devInfo, L"DriverVersion");
        SetupDiDestroyDeviceInfoList(devInfo);
        return regVersion;
    }
    SetupDiDestroyDeviceInfoList(devInfo);
    return L"";
}

static std::wstring GetDeviceDriverDate(USHORT vendorId, USHORT deviceId) {
    HDEVINFO devInfo = SetupDiGetClassDevsW(
        &GUID_DISPLAY_DEVICE_ARRIVAL, nullptr, nullptr,
        DIGCF_PRESENT);
    if (devInfo == INVALID_HANDLE_VALUE) return L"N/A";

    SP_DEVINFO_DATA devInfoData = {};
    devInfoData.cbSize = sizeof(devInfoData);

    for (DWORD i = 0; SetupDiEnumDeviceInfo(devInfo, i, &devInfoData); i++) {
        if (!MatchDisplayDeviceToAdapter(devInfoData, devInfo, vendorId, deviceId))
            continue;

        // Try DEVPKEY first
        FILETIME driverDate = {};
        if (SetupDiGetDevicePropertyW(devInfo, &devInfoData,
            &DEVPKEY_Device_DriverDate, nullptr,
            (PBYTE)&driverDate, sizeof(driverDate), nullptr, 0)) {
            SYSTEMTIME sysTime = {};
            if (FileTimeToSystemTime(&driverDate, &sysTime)) {
                wchar_t dateStr[32];
                swprintf(dateStr, 32, L"%d/%d/%d", sysTime.wMonth, sysTime.wDay, sysTime.wYear);
                SetupDiDestroyDeviceInfoList(devInfo);
                return dateStr;
            }
        }

        // Fallback to reading DriverDate from the driver registry key, which may be text or binary
        std::wstring regDate = GetDriverInfoFromRegistry(devInfoData, devInfo, L"DriverDateData");
        if (!regDate.empty()) {
            // DriverDateData is binary FILETIME, already handled above
        } else {
            regDate = GetDriverInfoFromRegistry(devInfoData, devInfo, L"DriverDate");
            if (!regDate.empty()) {
                // Convert dashes to slashes in the registry date
                for (auto& c : regDate) { if (c == L'-') c = L'/'; }
            }
        }
        SetupDiDestroyDeviceInfoList(devInfo);
        return regDate.empty() ? L"N/A" : regDate;
    }
    SetupDiDestroyDeviceInfoList(devInfo);
    return L"N/A";
}

static std::wstring GetDevicePhysicalLocation(USHORT vendorId, USHORT deviceId) {
    HDEVINFO devInfo = SetupDiGetClassDevsW(
        &GUID_DISPLAY_DEVICE_ARRIVAL, nullptr, nullptr,
        DIGCF_PRESENT);
    if (devInfo == INVALID_HANDLE_VALUE) return L"";

    SP_DEVINFO_DATA devInfoData = {};
    devInfoData.cbSize = sizeof(devInfoData);

    for (DWORD i = 0; SetupDiEnumDeviceInfo(devInfo, i, &devInfoData); i++) {
        if (!MatchDisplayDeviceToAdapter(devInfoData, devInfo, vendorId, deviceId))
            continue;

        WCHAR locationInfo[256] = {};
        if (SetupDiGetDeviceRegistryPropertyW(devInfo, &devInfoData,
            SPDRP_LOCATION_INFORMATION, nullptr,
            (PBYTE)locationInfo, sizeof(locationInfo), nullptr)) {
            SetupDiDestroyDeviceInfoList(devInfo);
            return locationInfo;
        }
    }
    SetupDiDestroyDeviceInfoList(devInfo);
    return L"";
}

static std::wstring GetDirectXFeatureLevel(IDXGIAdapter* adapter) {
    D3D_FEATURE_LEVEL levels[] = {
        D3D_FEATURE_LEVEL_12_1, D3D_FEATURE_LEVEL_12_0,
        D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0,
        D3D_FEATURE_LEVEL_9_3, D3D_FEATURE_LEVEL_9_2, D3D_FEATURE_LEVEL_9_1
    };
    D3D_FEATURE_LEVEL achieved = {};

    HRESULT hr = D3D11CreateDevice(
        adapter, D3D_DRIVER_TYPE_UNKNOWN, nullptr,
        0, levels, ARRAYSIZE(levels), D3D11_SDK_VERSION,
        nullptr, &achieved, nullptr);

    if (FAILED(hr)) return L"12";

    switch (achieved) {
        case D3D_FEATURE_LEVEL_12_1: return L"12 (FL 12.1)";
        case D3D_FEATURE_LEVEL_12_0: return L"12 (FL 12.0)";
        case D3D_FEATURE_LEVEL_11_1: return L"12 (FL 11.1)";
        case D3D_FEATURE_LEVEL_11_0: return L"12 (FL 11.0)";
        case D3D_FEATURE_LEVEL_10_1: return L"10.1";
        case D3D_FEATURE_LEVEL_10_0: return L"10.0";
        case D3D_FEATURE_LEVEL_9_3:  return L"9.3";
        case D3D_FEATURE_LEVEL_9_2:  return L"9.2";
        case D3D_FEATURE_LEVEL_9_1:  return L"9.1";
        default: return L"12";
    }
}

// Intel drivers expose a configured dedicated video memory size in the registry at
// HKLM Software Intel GMM as the DedicatedSegmentSize value in MB.
static uint64_t getIntelReportedDedicatedMB() {
    HKEY hKey;
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE,
        L"Software\\Intel\\GMM", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        DWORD value = 0;
        DWORD size = sizeof(value);
        if (RegQueryValueExW(hKey, L"DedicatedSegmentSize", NULL, NULL,
            (LPBYTE)&value, &size) == ERROR_SUCCESS) {
            RegCloseKey(hKey);
            return value; // Raw configured value; 0 means no dedicated segment
        }
        RegCloseKey(hKey);
    }
    return 0; // Key does not exist, so this is not an Intel GPU
}

void populateGpuInfo(SystemStats& stats) {
    if (g_fullAdapters.empty()) return;

    // Find the adapter with the most dedicated video memory (the discrete GPU)
    size_t bestIdx = 0;
    for (size_t i = 1; i < g_fullAdapters.size(); i++) {
        if (g_fullAdapters[i].desc.DedicatedVideoMemory > g_fullAdapters[bestIdx].desc.DedicatedVideoMemory) {
            bestIdx = i;
        }
    }
    const auto& adapter = g_fullAdapters[bestIdx];

    // Adapter description is the GPU model name as Task Manager shows it
    stats.gpuName = adapter.desc.Description;

    // Memory: PDH counters give usage matching Task Manager, and D3DKMT gives the commit limit
    double dedicatedUsedMB = 0.0;
    double sharedUsedMB = 0.0;
    double dedicatedCommittedMB = 0.0; // CommitLimit, the BIOS pre allocation used for the hardware reserved calculation

    if (g_gpuMemPdhReady) {
        PdhCollectQueryData(g_gpuMemQuery);

        // Sum the dedicated usage across all adapter instances
        {
            DWORD bufSize = 0, itemCount = 0;
            PDH_STATUS s1 = PdhGetFormattedCounterArrayW(g_gpuDedicatedCounter,
                PDH_FMT_DOUBLE, &bufSize, &itemCount, NULL);
            if (s1 == PDH_MORE_DATA && bufSize > 0) {
                BYTE* buf = new (std::nothrow) BYTE[bufSize];
                if (buf) {
                    s1 = PdhGetFormattedCounterArrayW(g_gpuDedicatedCounter,
                        PDH_FMT_DOUBLE, &bufSize, &itemCount,
                        reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buf));
                    if (s1 == ERROR_SUCCESS) {
                        auto* items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buf);
                        for (DWORD i = 0; i < itemCount; i++)
                            dedicatedUsedMB += items[i].FmtValue.doubleValue / (1024.0 * 1024.0);
                    }
                    delete[] buf;
                }
            }
        }

        // Sum the shared usage across all adapter instances
        {
            DWORD bufSize = 0, itemCount = 0;
            PDH_STATUS s2 = PdhGetFormattedCounterArrayW(g_gpuSharedCounter,
                PDH_FMT_DOUBLE, &bufSize, &itemCount, NULL);
            if (s2 == PDH_MORE_DATA && bufSize > 0) {
                BYTE* buf = new (std::nothrow) BYTE[bufSize];
                if (buf) {
                    s2 = PdhGetFormattedCounterArrayW(g_gpuSharedCounter,
                        PDH_FMT_DOUBLE, &bufSize, &itemCount,
                        reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buf));
                    if (s2 == ERROR_SUCCESS) {
                        auto* items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buf);
                        for (DWORD i = 0; i < itemCount; i++)
                            sharedUsedMB += items[i].FmtValue.doubleValue / (1024.0 * 1024.0);
                    }
                    delete[] buf;
                }
            }
        }
    } else {
        // Fallback to D3DKMT segment queries
        if (g_adapterHandle && g_segmentCount > 0) {
            for (ULONG s = 0; s < g_segmentCount; s++) {
                D3DKMT_QUERYSTATISTICS queryStats = {};
                queryStats.Type = D3DKMT_QUERYSTATISTICS_SEGMENT;
                queryStats.AdapterLuid = adapter.adapterLuid;
                queryStats.QuerySegment.SegmentId = s;
                NTSTATUS segStatus = pQueryStatistics(&queryStats);
                if (segStatus >= 0) {
                    ULONG64 bytesResident = queryStats.QueryResult.SegmentInformation.BytesResident;
                    if (g_apertureSegments[s])
                        sharedUsedMB += (double)bytesResident / (1024.0 * 1024.0);
                    else
                        dedicatedUsedMB += (double)bytesResident / (1024.0 * 1024.0);
                }
            }
        }
    }

    // The D3DKMT commit limit is always needed for the hardware reserved calculation
    if (g_adapterHandle && g_segmentCount > 0) {
        for (ULONG s = 0; s < g_segmentCount; s++) {
            if (!g_apertureSegments[s]) {
                D3DKMT_QUERYSTATISTICS queryStats = {};
                queryStats.Type = D3DKMT_QUERYSTATISTICS_SEGMENT;
                queryStats.AdapterLuid = adapter.adapterLuid;
                queryStats.QuerySegment.SegmentId = s;
                NTSTATUS segStatus = pQueryStatistics(&queryStats);
                if (segStatus >= 0) {
                    ULONG64 commitLimit = queryStats.QueryResult.SegmentInformation.CommitLimit;
                    dedicatedCommittedMB += (double)commitLimit / (1024.0 * 1024.0);
                }
            }
        }
    }

    // Total capacity mirrors Task Manager. Intel integrated GPUs report a fixed
    // 128 MB dedicated total (the "fictitious" DDP/DVMT default) even though the
    // actual reserved segment is smaller; hardware reserved is that difference
    // (128 - committed). Only report the 128 default when a real dedicated
    // segment exists (>0). When the adapter genuinely has no dedicated memory
    // (DXGI reports ~0), report 0 so the UI matches Task Manager hiding the row.
    bool isIntel = (adapter.desc.VendorId == 0x8086);
    double dedVideoMB = (double)adapter.desc.DedicatedVideoMemory / (1024.0 * 1024.0);
    double dedSysMB = (double)adapter.desc.DedicatedSystemMemory / (1024.0 * 1024.0);
    double realDedicatedMB = dedVideoMB + dedSysMB;

    double dedicatedTotalMB;
    uint64_t intelRegistryMB = isIntel ? getIntelReportedDedicatedMB() : 0;

    if (intelRegistryMB > 0) {
        dedicatedTotalMB = (double)intelRegistryMB;
    } else if (isIntel && realDedicatedMB > 0.5) {
        // Task Manager's fixed "Dedicated GPU memory" total for Intel iGPUs
        dedicatedTotalMB = 128.0;
    } else {
        dedicatedTotalMB = realDedicatedMB;
    }

    double sharedTotalMB = (g_segmentInfoValid)
        ? (double)g_segmentSizeInfo.SharedSystemMemorySize / (1024.0 * 1024.0)
        : (double)adapter.desc.SharedSystemMemory / (1024.0 * 1024.0);

    // Hardware reserved is the difference between reported and actual BIOS pre allocated memory
    double hardwareReservedMB = dedicatedTotalMB - dedicatedCommittedMB;
    if (hardwareReservedMB < 0) hardwareReservedMB = 0;

    // Assign values
    stats.gpuDedicatedMB = dedicatedUsedMB;
    stats.gpuSharedMB = sharedUsedMB;
    stats.gpuDedicatedTotalMB = dedicatedTotalMB;
    stats.gpuSharedTotalMB = sharedTotalMB;
    stats.gpuTotalMemoryMB = dedicatedTotalMB + sharedTotalMB;
    stats.gpuHardwareReservedMB = hardwareReservedMB;

    // Driver version from SetupAPI, matched by PCI vendor and device id
    stats.gpuDriverVersion = GetDeviceDriverVersion(adapter.desc.VendorId, adapter.desc.DeviceId);

    // Driver date from SetupAPI
    stats.gpuDriverDate = GetDeviceDriverDate(adapter.desc.VendorId, adapter.desc.DeviceId);

    // DirectX feature level from a D3D11 probe
    if (adapter.dxgiAdapter) {
        stats.gpuDirectXVersion = GetDirectXFeatureLevel(adapter.dxgiAdapter);
    } else {
        stats.gpuDirectXVersion = L"12";
    }

    // PCI physical location from SetupAPI
    stats.gpuPhysicalLocation = GetDevicePhysicalLocation(adapter.desc.VendorId, adapter.desc.DeviceId);
}
