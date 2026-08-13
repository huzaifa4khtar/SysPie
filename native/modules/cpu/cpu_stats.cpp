// SysPie CPU Stats
// CPU usage comes from SystemProcessorPerformanceInformation and memory from
// SystemPerformanceInformation, both via NtQuerySystemInformation.
// Ported from System Informer's PhpUpdateCpuInformation and PhpUpdatePerfInformation.

#include "cpu/cpu_stats.h"
#include "common/nt_types.h"
#include "cpu/cpu_percent_math.h"
#include <thread>
#include <mutex>
#include <atomic>

#include <windows.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <comdef.h>
#include <Wbemidl.h>

#pragma comment(lib, "pdh.lib")
#pragma comment(lib, "wbemuuid.lib")
#include <vector>
#include <cstring>
#include <intrin.h>

// PDH counter for real time CPU speed

static PDH_HQUERY g_speedQuery = nullptr;
static PDH_HCOUNTER g_speedCounter = nullptr;
static bool g_speedPdhInit = false;

// System-wide CPU sampler. A dedicated thread computes percentage deltas on a fixed 1s
// cadence and caches them, so getSystemStats reads stable values instead of computing
// deltas on demand from whichever caller happens to run.

namespace {
std::mutex g_cpuMutex;
double g_cpuUsage = 0.0;
double g_cpuKernel = 0.0;
double g_cpuUser = 0.0;
std::uint64_t g_prevBusyKernel = 0;
std::uint64_t g_prevUser = 0;
std::uint64_t g_prevIdle = 0;
bool g_havePrev = false;
std::atomic<bool> g_cpuSamplerRunning{false};
std::thread g_cpuSamplerThread;
std::once_flag g_cpuSamplerOnce;
}

// WMI memory info for speed and type, queried once and cached

struct WmiMemoryInfo {
    uint32_t speedMHz = 0;
    std::wstring memoryType;
    bool queried = false;
};

static WmiMemoryInfo getWmiMemoryInfo() {
    static WmiMemoryInfo cached;
    if (cached.queried) return cached;

    HRESULT hr = CoInitializeEx(0, COINIT_MULTITHREADED);
    bool comInited = SUCCEEDED(hr);

    if (hr == RPC_E_CHANGED_MODE) {
        comInited = false;
    } else if (FAILED(hr) && hr != S_FALSE) {
        return cached;
    }

    hr = CoInitializeSecurity(NULL, -1, NULL, NULL,
        RPC_C_AUTHN_LEVEL_DEFAULT, RPC_C_IMP_LEVEL_IMPERSONATE,
        NULL, EOAC_NONE, NULL);
    if (FAILED(hr) && hr != RPC_E_TOO_LATE) {
        if (comInited) CoUninitialize();
        return cached;
    }

    IWbemLocator* pLocator = nullptr;
    hr = CoCreateInstance(CLSID_WbemLocator, 0, CLSCTX_INPROC_SERVER,
        IID_IWbemLocator, (void**)&pLocator);
    if (FAILED(hr)) {
        if (comInited) CoUninitialize();
        return cached;
    }

    IWbemServices* pServices = nullptr;
    hr = pLocator->ConnectServer(
        _bstr_t(L"ROOT\\CIMV2"), NULL, NULL, 0, 0, 0, 0, &pServices);
    if (FAILED(hr)) {
        pLocator->Release();
        if (comInited) CoUninitialize();
        return cached;
    }

    hr = CoSetProxyBlanket(pServices,
        RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, NULL,
        RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE,
        NULL, EOAC_NONE);
    if (FAILED(hr)) {
        pServices->Release();
        pLocator->Release();
        if (comInited) CoUninitialize();
        return cached;
    }

    IEnumWbemClassObject* pEnumerator = nullptr;
    hr = pServices->ExecQuery(
        bstr_t("WQL"),
        bstr_t("SELECT Speed, SMBIOSMemoryType FROM Win32_PhysicalMemory"),
        WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
        NULL, &pEnumerator);
    if (SUCCEEDED(hr)) {
        IWbemClassObject* pObj = nullptr;
        ULONG returned = 0;
        while (pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &returned) == S_OK) {
            VARIANT vtSpeed, vtType;
            VariantInit(&vtSpeed);
            VariantInit(&vtType);
            pObj->Get(L"Speed", 0, &vtSpeed, 0, 0);
            pObj->Get(L"SMBIOSMemoryType", 0, &vtType, 0, 0);

            if ((vtSpeed.vt == VT_I4 || vtSpeed.vt == VT_UI4) && vtSpeed.uintVal > 0) {
                if (vtSpeed.uintVal > cached.speedMHz) {
                    cached.speedMHz = vtSpeed.uintVal;
                }
            }
            if ((vtType.vt == VT_I4 || vtType.vt == VT_UI4) && cached.memoryType.empty()) {
                BYTE mt = (BYTE)vtType.uintVal;
                switch (mt) {
                    case 0x00: cached.memoryType = L"Other"; break;
                    case 0x01: cached.memoryType = L"Unknown"; break;
                    case 0x02: cached.memoryType = L"DRAM"; break;
                    case 0x03: cached.memoryType = L"SDRAM"; break;
                    case 0x04: cached.memoryType = L"Cache DRAM"; break;
                    case 0x05: cached.memoryType = L"EDO"; break;
                    case 0x06: cached.memoryType = L"EDRAM"; break;
                    case 0x07: cached.memoryType = L"VRAM"; break;
                    case 0x08: cached.memoryType = L"SRAM"; break;
                    case 0x09: cached.memoryType = L"RAM"; break;
                    case 0x0A: cached.memoryType = L"ROM"; break;
                    case 0x0B: cached.memoryType = L"Flash"; break;
                    case 0x0C: cached.memoryType = L"EEPROM"; break;
                    case 0x0D: cached.memoryType = L"FEPROM"; break;
                    case 0x0E: cached.memoryType = L"EPROM"; break;
                    case 0x0F: cached.memoryType = L"CDRAM"; break;
                    case 0x10: cached.memoryType = L"3DRAM"; break;
                    case 0x11: cached.memoryType = L"SDRAM"; break;
                    case 0x12: cached.memoryType = L"SGRAM"; break;
                    case 0x13: cached.memoryType = L"RDRAM"; break;
                    case 0x14: cached.memoryType = L"DDR"; break;
                    case 0x15: cached.memoryType = L"DDR2"; break;
                    case 0x16: cached.memoryType = L"DDR2 FB-DIMM"; break;
                    case 0x18: cached.memoryType = L"DDR3"; break;
                    case 0x19: cached.memoryType = L"FBD2"; break;
                    case 0x1A: cached.memoryType = L"DDR4"; break;
                    case 0x1B: cached.memoryType = L"LPDDR"; break;
                    case 0x1C: cached.memoryType = L"LPDDR2"; break;
                    case 0x1D: cached.memoryType = L"LPDDR3"; break;
                    case 0x1E: cached.memoryType = L"LPDDR4"; break;
                    case 0x1F: cached.memoryType = L"LPDDR4X"; break;
                    case 0x20: cached.memoryType = L"DDR5"; break;
                    case 0x21: cached.memoryType = L"LPDDR5"; break;
                    default: cached.memoryType = L"Other"; break;
                }
            }

            VariantClear(&vtSpeed);
            VariantClear(&vtType);
            pObj->Release();
        }
        pEnumerator->Release();
    }

    pServices->Release();
    pLocator->Release();
    if (comInited) CoUninitialize();

    cached.queried = true;
    return cached;
}

// One CPU sample at a fixed cadence. Cumulative NT counters are read, a delta is computed
// against the previous sample and the resulting percentages are cached under the mutex.
static void cpuSampleOnce() {
    SYSTEM_BASIC_INFORMATION basicInfo = {};
    NtQuerySystemInformation(SystemBasicInformation, &basicInfo, sizeof(basicInfo), NULL);
    ULONG numProcessors = basicInfo.NumberOfProcessors;
    if (numProcessors == 0 || numProcessors > 256) numProcessors = 256;

    std::vector<SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION> cpuInfo(numProcessors);
    NTSTATUS status = NtQuerySystemInformation(
        SystemProcessorPerformanceInformation, cpuInfo.data(),
        sizeof(SYSTEM_PROCESSOR_PERFORMANCE_INFORMATION) * numProcessors, NULL);
    if (!NT_SUCCESS(status)) return;

    std::uint64_t totalKernel = 0;
    std::uint64_t totalUser = 0;
    std::uint64_t totalIdle = 0;
    for (ULONG i = 0; i < numProcessors; i++) {
        // KernelTime includes IdleTime, so subtract it, the same as System Informer.
        totalKernel += cpuInfo[i].KernelTime.QuadPart - cpuInfo[i].IdleTime.QuadPart;
        totalUser += cpuInfo[i].UserTime.QuadPart;
        totalIdle += cpuInfo[i].IdleTime.QuadPart;
    }

    std::lock_guard<std::mutex> lock(g_cpuMutex);
    if (!g_havePrev) {
        g_prevBusyKernel = totalKernel;
        g_prevUser = totalUser;
        g_prevIdle = totalIdle;
        g_havePrev = true;
        return; // First sample only establishes the baseline.
    }
    CpuPercentages p = computeCpuPercent(
        g_prevBusyKernel, totalKernel,
        g_prevUser, totalUser,
        g_prevIdle, totalIdle);
    g_cpuUsage = p.usage;
    g_cpuKernel = p.kernel;
    g_cpuUser = p.user;
    g_prevBusyKernel = totalKernel;
    g_prevUser = totalUser;
    g_prevIdle = totalIdle;
}

static void cpuSamplerThreadFunc() {
    while (g_cpuSamplerRunning.load(std::memory_order_relaxed)) {
        Sleep(1000);
        cpuSampleOnce();
    }
}

// Idempotent start, safe to call from any thread that needs CPU stats.
static void cpuSamplerStart() {
    std::call_once(g_cpuSamplerOnce, [] {
        g_cpuSamplerRunning.store(true, std::memory_order_relaxed);
        g_cpuSamplerThread = std::thread(cpuSamplerThreadFunc);
        g_cpuSamplerThread.detach();
    });
}

// System stats, mirroring System Informer's PhpUpdateCpuInformation and PhpUpdatePerfInformation

SystemStats getSystemStats() {
    SystemStats stats = {};

    // Get basic system info for processor count and memory
    SYSTEM_BASIC_INFORMATION basicInfo = {};
    NtQuerySystemInformation(SystemBasicInformation, &basicInfo, sizeof(basicInfo), NULL);
    ULONG numProcessors = basicInfo.NumberOfProcessors;

    // CPU logical processors from basic info
    stats.cpuLogicalProcessors = basicInfo.NumberOfProcessors;

    // CPU base speed and model name from registry, the model name only needs reading once
    static std::wstring cachedCpuName;
    HKEY hKey;
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE,
        L"HARDWARE\\DESCRIPTION\\SYSTEM\\CentralProcessor\\0", 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        DWORD mhz = 0;
        DWORD size = sizeof(mhz);
        RegQueryValueExW(hKey, L"~MHz", nullptr, nullptr, (LPBYTE)&mhz, &size);
        stats.cpuBaseSpeedMHz = (double)mhz;

        // Full model string, for example Intel Core i5-4310U
        if (cachedCpuName.empty()) {
            DWORD nameSize = 0;
            RegQueryValueExW(hKey, L"ProcessorNameString", nullptr, nullptr, nullptr, &nameSize);
            if (nameSize > 0) {
                cachedCpuName.resize(nameSize / sizeof(wchar_t));
                RegQueryValueExW(hKey, L"ProcessorNameString", nullptr, nullptr,
                    (LPBYTE)&cachedCpuName[0], &nameSize);
                // The value is NUL terminated, so drop the trailing terminator
                while (!cachedCpuName.empty() && cachedCpuName.back() == L'\0') {
                    cachedCpuName.pop_back();
                }
            }
        }
        RegCloseKey(hKey);
    }
    stats.cpuName = cachedCpuName;

    // Current speed is base speed times percent Processor Performance.
    // PDH rate counters need a persistent query primed with two samples to give valid data.
    if (!g_speedPdhInit) {
        g_speedPdhInit = true;
        if (PdhOpenQuery(nullptr, 0, &g_speedQuery) == ERROR_SUCCESS) {
            if (PdhAddEnglishCounterW(g_speedQuery,
                L"\\Processor Information(_Total)\\% Processor Performance", 0, &g_speedCounter) == ERROR_SUCCESS) {
                // Prime with two samples, the same pattern as the GPU engine collector file
                PdhCollectQueryData(g_speedQuery);
                Sleep(100);
                PdhCollectQueryData(g_speedQuery);
            } else {
                PdhCloseQuery(g_speedQuery);
                g_speedQuery = nullptr;
                g_speedCounter = nullptr;
            }
        }
    }

    if (g_speedQuery && g_speedCounter) {
        PdhCollectQueryData(g_speedQuery);
        PDH_FMT_COUNTERVALUE fmtValue;
        PDH_STATUS status = PdhGetFormattedCounterValue(g_speedCounter, PDH_FMT_DOUBLE, nullptr, &fmtValue);
        if (status == ERROR_SUCCESS && fmtValue.CStatus == PDH_CSTATUS_VALID_DATA) {
            stats.cpuSpeedMHz = stats.cpuBaseSpeedMHz * (fmtValue.doubleValue / 100.0);
        } else {
            stats.cpuSpeedMHz = stats.cpuBaseSpeedMHz;
        }
    } else {
        stats.cpuSpeedMHz = stats.cpuBaseSpeedMHz;
    }

    // CPU cores and cache sizes via GetLogicalProcessorInformation
    DWORD bufferSize = 0;
    GetLogicalProcessorInformation(nullptr, &bufferSize);
    std::vector<SYSTEM_LOGICAL_PROCESSOR_INFORMATION> buffer(bufferSize / sizeof(SYSTEM_LOGICAL_PROCESSOR_INFORMATION));
    if (GetLogicalProcessorInformation(buffer.data(), &bufferSize)) {
        uint32_t physicalCores = 0;
        for (const auto& info : buffer) {
            if (info.Relationship == RelationCache) {
                if (info.Cache.Level == 1) stats.cpuL1CacheKB += info.Cache.Size / 1024;
                else if (info.Cache.Level == 2) stats.cpuL2CacheKB += info.Cache.Size / 1024;
                else if (info.Cache.Level == 3) stats.cpuL3CacheKB = info.Cache.Size / 1024;
            } else if (info.Relationship == RelationProcessorCore) {
                physicalCores++;
            }
        }
        stats.cpuCores = physicalCores;
    }

    // Assume one socket, which is correct for most desktops and laptops
    stats.cpuSockets = 1;

    // Virtualization is enabled in firmware when the VIRT FIRMWARE ENABLED feature is present, matching Task Manager.
    stats.cpuVirtualization = IsProcessorFeaturePresent(0x17);

    // System uptime from GetTickCount64, converting milliseconds to seconds
    stats.uptimeSeconds = GetTickCount64() / 1000ULL;

    // CPU percentages come from the dedicated sampler thread, which keeps a fixed 1s delta
    // window and avoids caller-cadence races on the shared global deltas.
    cpuSamplerStart();

    {
        std::lock_guard<std::mutex> lock(g_cpuMutex);
        stats.cpuUsagePercent = g_cpuUsage;
        stats.cpuKernelPercent = g_cpuKernel;
        stats.cpuUserPercent = g_cpuUser;
    }

    // Get physical RAM from GlobalMemoryStatusEx, the same API Task Manager uses.
    // Commit charge and limit come from SystemPerformanceInformation, which MEMORYSTATUSEX does not provide.
    MEMORYSTATUSEX memStatus = {};
    memStatus.dwLength = sizeof(memStatus);
    if (GlobalMemoryStatusEx(&memStatus)) {
        stats.totalPhysicalMB = (double)memStatus.ullTotalPhys / (1024.0 * 1024.0);
        stats.availablePhysicalMB = (double)memStatus.ullAvailPhys / (1024.0 * 1024.0);
        stats.usedPhysicalMB = stats.totalPhysicalMB - stats.availablePhysicalMB;
    }

    // Commit charge and limit from the NT API, kept separate from physical RAM
    alignas(16) BYTE perfBuffer[1024] = {};
    NTSTATUS perfStatus = NtQuerySystemInformation(
        SystemPerformanceInformation, perfBuffer, sizeof(perfBuffer), NULL);
    double pageSizeMB = (double)basicInfo.PageSize / (1024.0 * 1024.0);
    if (perfStatus >= 0) {
        ULONG committedPages = *(ULONG*)(perfBuffer + 48);
        ULONG commitLimit = *(ULONG*)(perfBuffer + 52);
        stats.commitChargeMB = (double)committedPages * pageSizeMB;
        stats.commitLimitMB = (double)commitLimit * pageSizeMB;

        // Paged pool and nonpaged pool come from SystemPerformanceInformation
        ULONG pagedPoolPages = *(ULONG*)(perfBuffer + 112);
        ULONG nonPagedPoolPages = *(ULONG*)(perfBuffer + 116);
        stats.memoryPagedPoolMB = (double)pagedPoolPages * pageSizeMB;
        stats.memoryNonPagedPoolMB = (double)nonPagedPoolPages * pageSizeMB;
    }

    // Cached memory via PDH counters matches Task Manager. It sums Cache Bytes,
    // Modified Page List Bytes, and the standby cache values.
    {
        PDH_HQUERY hQuery = nullptr;
        if (PdhOpenQuery(nullptr, 0, &hQuery) == ERROR_SUCCESS) {
            PDH_HCOUNTER hCacheBytes = nullptr;
            PDH_HCOUNTER hModified = nullptr;
            PDH_HCOUNTER hStandbyReserve = nullptr;
            PDH_HCOUNTER hStandbyNormal = nullptr;
            PDH_HCOUNTER hStandbyCode = nullptr;

            PdhAddEnglishCounterW(hQuery, L"\\Memory\\Cache Bytes", 0, &hCacheBytes);
            PdhAddEnglishCounterW(hQuery, L"\\Memory\\Modified Page List Bytes", 0, &hModified);
            PdhAddEnglishCounterW(hQuery, L"\\Memory\\Standby Cache Reserve Bytes", 0, &hStandbyReserve);
            PdhAddEnglishCounterW(hQuery, L"\\Memory\\Standby Cache Normal Priority Bytes", 0, &hStandbyNormal);
            PdhAddEnglishCounterW(hQuery, L"\\Memory\\Standby Cache Core Bytes", 0, &hStandbyCode);

            PdhCollectQueryData(hQuery);

            double cachedBytes = 0;
            PDH_FMT_COUNTERVALUE fmtVal;

            if (hCacheBytes && PdhGetFormattedCounterValue(hCacheBytes, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS)
                cachedBytes += fmtVal.doubleValue;
            if (hModified && PdhGetFormattedCounterValue(hModified, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS)
                cachedBytes += fmtVal.doubleValue;
            if (hStandbyReserve && PdhGetFormattedCounterValue(hStandbyReserve, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS)
                cachedBytes += fmtVal.doubleValue;
            if (hStandbyNormal && PdhGetFormattedCounterValue(hStandbyNormal, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS)
                cachedBytes += fmtVal.doubleValue;
            if (hStandbyCode && PdhGetFormattedCounterValue(hStandbyCode, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS)
                cachedBytes += fmtVal.doubleValue;

            stats.memoryCachedMB = cachedBytes / (1024.0 * 1024.0);
            PdhCloseQuery(hQuery);
        }
    }

    // Memory speed, slots, and form factor come from SMBIOS type 17 memory device entries
    DWORD smbiosSize = GetSystemFirmwareTable('RSMB', 0, nullptr, 0);
    if (smbiosSize > 0) {
        std::vector<BYTE> smbiosData(smbiosSize);
        if (GetSystemFirmwareTable('RSMB', 0, smbiosData.data(), smbiosSize) > 0) {
            #pragma pack(push, 1)
            struct RawSMBIOSDataHeader {
                BYTE Used20CallingMethod;
                BYTE SMBIOSMajorVersion;
                BYTE SMBIOSMinorVersion;
                BYTE DmiRevision;
                DWORD Length;
            };
            #pragma pack(pop)

            auto* smbiosHeader = (RawSMBIOSDataHeader*)smbiosData.data();
            BYTE* rawSmbios = smbiosData.data() + sizeof(RawSMBIOSDataHeader);
            DWORD remaining = smbiosHeader->Length;
            if (remaining > smbiosSize - sizeof(RawSMBIOSDataHeader)) {
                remaining = smbiosSize - sizeof(RawSMBIOSDataHeader);
            }

            uint32_t slotCount = 0;
            uint32_t slotUsed = 0;
            double totalInstalledMB = 0;
            bool haveFormFactor = false;
            bool haveMemType = false;

            while (remaining > 4) {
                BYTE* entry = rawSmbios;
                BYTE type = entry[0];
                WORD structLen = entry[1];
                if (structLen < 4 || structLen > remaining) break;

                if (type == 17 && structLen >= 21) {
                    slotCount++;
                    // Size is a WORD at offset 0x0C, in MB unless bit 15 is set, in which case it is KB
                    WORD sizeField = *(WORD*)(entry + 0x0C);
                    if (sizeField != 0 && sizeField != 0x7FFF) {
                        slotUsed++;
                        if (sizeField & 0x8000) {
                            totalInstalledMB += (double)(sizeField & 0x7FFF) / 1024.0;
                        } else {
                            totalInstalledMB += (double)sizeField;
                        }

                        // Only store form factor and memory type from populated slots
                        if (!haveFormFactor) {
                            BYTE formFactor = entry[0x0E];
                            switch (formFactor) {
                                case 0x02: stats.memoryFormFactor = L"Other"; break;
                                case 0x03: stats.memoryFormFactor = L"Unknown"; break;
                                case 0x04: stats.memoryFormFactor = L"SIMM"; break;
                                case 0x05: stats.memoryFormFactor = L"PIP"; break;
                                case 0x06: stats.memoryFormFactor = L"SOCKET"; break;
                                case 0x07: stats.memoryFormFactor = L"JP"; break;
                                case 0x08: stats.memoryFormFactor = L"LPDIMM"; break;
                                case 0x09: stats.memoryFormFactor = L"DIMM"; break;
                                case 0x0A: stats.memoryFormFactor = L"RIMM"; break;
                                case 0x0B: stats.memoryFormFactor = L"SODIMM"; break;
                                case 0x0C: stats.memoryFormFactor = L"RIMM"; break;
                                case 0x0D: stats.memoryFormFactor = L"SODIMM"; break;
                                case 0x0E: stats.memoryFormFactor = L"FBGA"; break;
                                case 0x0F: stats.memoryFormFactor = L"CSP"; break;
                                default: stats.memoryFormFactor = L"Other"; break;
                            }
                            haveFormFactor = true;
                        }

                        // Memory type is a byte at offset 0x11, using SMBIOS spec values
                        if (!haveMemType) {
                            BYTE memType = entry[0x11];
                            switch (memType) {
                                case 0x00: stats.memoryType = L"Other"; break;
                                case 0x01: stats.memoryType = L"Unknown"; break;
                                case 0x02: stats.memoryType = L"DRAM"; break;
                                case 0x03: stats.memoryType = L"SDRAM"; break;
                                case 0x04: stats.memoryType = L"Cache DRAM"; break;
                                case 0x05: stats.memoryType = L"EDO"; break;
                                case 0x06: stats.memoryType = L"EDRAM"; break;
                                case 0x07: stats.memoryType = L"VRAM"; break;
                                case 0x08: stats.memoryType = L"SRAM"; break;
                                case 0x09: stats.memoryType = L"RAM"; break;
                                case 0x0A: stats.memoryType = L"ROM"; break;
                                case 0x0B: stats.memoryType = L"Flash"; break;
                                case 0x0C: stats.memoryType = L"EEPROM"; break;
                                case 0x0D: stats.memoryType = L"FEPROM"; break;
                                case 0x0E: stats.memoryType = L"EPROM"; break;
                                case 0x0F: stats.memoryType = L"CDRAM"; break;
                                case 0x10: stats.memoryType = L"3DRAM"; break;
                                case 0x11: stats.memoryType = L"SDRAM"; break;
                                case 0x12: stats.memoryType = L"SGRAM"; break;
                                case 0x13: stats.memoryType = L"RDRAM"; break;
                                case 0x14: stats.memoryType = L"DDR"; break;
                                case 0x15: stats.memoryType = L"DDR2"; break;
                                case 0x16: stats.memoryType = L"DDR2 FB-DIMM"; break;
                                case 0x18: stats.memoryType = L"DDR3"; break;
                                case 0x19: stats.memoryType = L"FBD2"; break;
                                case 0x1A: stats.memoryType = L"DDR4"; break;
                                case 0x1B: stats.memoryType = L"LPDDR"; break;
                                case 0x1C: stats.memoryType = L"LPDDR2"; break;
                                case 0x1D: stats.memoryType = L"LPDDR3"; break;
                                case 0x1E: stats.memoryType = L"LPDDR4"; break;
                                case 0x1F: stats.memoryType = L"LPDDR4X"; break;
                                case 0x20: stats.memoryType = L"DDR5"; break;
                                case 0x21: stats.memoryType = L"LPDDR5"; break;
                                default: stats.memoryType = L"Other"; break;
                            }
                            haveMemType = true;
                        }
                    }
                }

                rawSmbios += structLen;
                remaining -= structLen;
                while (remaining > 1 && !(rawSmbios[0] == 0 && rawSmbios[1] == 0)) {
                    rawSmbios++; remaining--;
                }
                if (remaining >= 2) { rawSmbios += 2; remaining -= 2; } else { break; }
            }
            stats.memorySlotsTotal = slotCount;
            stats.memorySlotsUsed = slotUsed;

            // Hardware reserved is total installed from SMBIOS minus the OS usable amount
            if (totalInstalledMB > 0) {
                stats.memoryHardwareReservedMB = totalInstalledMB - stats.totalPhysicalMB;
                if (stats.memoryHardwareReservedMB < 0) stats.memoryHardwareReservedMB = 0;
            }
        }
    }

    // If SMBIOS did not give hardware reserved, fall back to GetPhysicallyInstalledSystemMemory
    if (stats.memoryHardwareReservedMB <= 0) {
        ULONGLONG installedKB = 0;
        if (GetPhysicallyInstalledSystemMemory(&installedKB)) {
            double installedMB = (double)installedKB / 1024.0;
            double usableMB = (double)memStatus.ullTotalPhys / (1024.0 * 1024.0);
            stats.memoryHardwareReservedMB = installedMB - usableMB;
            if (stats.memoryHardwareReservedMB < 0) stats.memoryHardwareReservedMB = 0;
        }
    }

    // WMI fallback for speed and memory type, since SMBIOS is often unreliable
    WmiMemoryInfo wmi = getWmiMemoryInfo();
    if (stats.memorySpeedMHz == 0 && wmi.speedMHz > 0) {
        stats.memorySpeedMHz = wmi.speedMHz;
    }
    if ((stats.memoryType.empty() || stats.memoryType == L"Other" || stats.memoryType == L"Unknown")
        && !wmi.memoryType.empty() && wmi.memoryType != L"Other" && wmi.memoryType != L"Unknown") {
        stats.memoryType = wmi.memoryType;
    }

    return stats;
}
