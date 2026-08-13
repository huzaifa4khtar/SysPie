// SysPie Disk Stats
// Disk metrics via PDH counters, GetDiskFreeSpaceEx, and WMI.
// Matches Windows Task Manager data sources.

#include "disk/disk_stats.h"

#include <windows.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <ole2.h>
#include <comdef.h>
#include <Wbemidl.h>

#pragma comment(lib, "pdh.lib")

// Persistent PDH query for disk counters

static PDH_HQUERY g_diskQuery = nullptr;
static PDH_HCOUNTER g_diskActivePct = nullptr;
static PDH_HCOUNTER g_diskAvgTransfer = nullptr;
static PDH_HCOUNTER g_diskReadBytes = nullptr;
static PDH_HCOUNTER g_diskWriteBytes = nullptr;
static bool g_diskPdhInit = false;

static void initDiskPdh() {
    if (g_diskPdhInit) return;
    g_diskPdhInit = true;

    if (PdhOpenQuery(nullptr, 0, &g_diskQuery) != ERROR_SUCCESS) return;

    PdhAddEnglishCounterW(g_diskQuery,
        L"\\PhysicalDisk(_Total)\\% Disk Time", 0, &g_diskActivePct);
    PdhAddEnglishCounterW(g_diskQuery,
        L"\\PhysicalDisk(_Total)\\Avg. Disk sec/Transfer", 0, &g_diskAvgTransfer);
    PdhAddEnglishCounterW(g_diskQuery,
        L"\\PhysicalDisk(_Total)\\Disk Read Bytes/sec", 0, &g_diskReadBytes);
    PdhAddEnglishCounterW(g_diskQuery,
        L"\\PhysicalDisk(_Total)\\Disk Write Bytes/sec", 0, &g_diskWriteBytes);

    PdhCollectQueryData(g_diskQuery);
    Sleep(100);
    PdhCollectQueryData(g_diskQuery);
}

// getSystemDiskStats returns disk read and write bytes per second via PDH

void getSystemDiskStats(double& readBytesPerSec, double& writeBytesPerSec) {
    readBytesPerSec = 0.0;
    writeBytesPerSec = 0.0;

    initDiskPdh();
    if (!g_diskQuery) return;

    PdhCollectQueryData(g_diskQuery);
    PDH_FMT_COUNTERVALUE fmtVal;

    if (g_diskReadBytes &&
        PdhGetFormattedCounterValue(g_diskReadBytes, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS) {
        readBytesPerSec = fmtVal.doubleValue;
    }
    if (g_diskWriteBytes &&
        PdhGetFormattedCounterValue(g_diskWriteBytes, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS) {
        writeBytesPerSec = fmtVal.doubleValue;
    }
}

// getDiskTypeViaWmi queries the MediaType property of the MSFT PhysicalDisk WMI class
// without admin rights, returning SSD, HDD, or an empty string. The result is cached after the first call.

static std::wstring getDiskTypeViaWmi() {
    static std::wstring cachedType;
    static bool queried = false;
    if (queried) return cachedType;
    queried = true;

    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    bool comInit = SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;
    if (!comInit) return L"";

    IWbemLocator* pLocator = nullptr;
    hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER,
        IID_IWbemLocator, (void**)&pLocator);
    if (FAILED(hr)) { CoUninitialize(); return L""; }

    IWbemServices* pServices = nullptr;
    hr = pLocator->ConnectServer(
        bstr_t(L"ROOT\\microsoft\\windows\\storage"),
        nullptr, nullptr, nullptr, 0, nullptr, nullptr, &pServices);
    if (FAILED(hr)) {
        pLocator->Release();
        CoUninitialize();
        return L"";
    }

    hr = CoSetProxyBlanket(pServices, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE,
        nullptr, RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE,
        nullptr, EOAC_NONE);

    IEnumWbemClassObject* pEnumerator = nullptr;
    hr = pServices->ExecQuery(
        bstr_t(L"WQL"),
        bstr_t(L"SELECT MediaType FROM MSFT_PhysicalDisk"),
        WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
        nullptr, &pEnumerator);

    if (SUCCEEDED(hr)) {
        IWbemClassObject* pObj = nullptr;
        ULONG returned = 0;
        hr = pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &returned);
        if (SUCCEEDED(hr) && returned > 0) {
            VARIANT vtMediaType;
            VariantInit(&vtMediaType);
            hr = pObj->Get(L"MediaType", 0, &vtMediaType, nullptr, nullptr);
            if (SUCCEEDED(hr) && vtMediaType.vt == VT_I4) {
                if (vtMediaType.intVal == 4 || vtMediaType.intVal == 5) {
                    cachedType = L"SSD";
                } else if (vtMediaType.intVal == 3) {
                    cachedType = L"HDD";
                }
            }
            VariantClear(&vtMediaType);
            pObj->Release();
        }
        pEnumerator->Release();
    }

    pServices->Release();
    pLocator->Release();
    CoUninitialize();

    return cachedType;
}

// getDiskCapacityViaWmi queries total physical disk capacity via WMI without admin rights.
// It tries the Win32 DiskDrive class in the cimv2 namespace first, then the MSFT Disk class
// in the storage namespace. It returns total bytes on the first physical disk or 0 on failure,
// and caches the result after the first call.

// Cached disk model, captured once alongside the capacity query
static std::wstring g_diskModel;

std::wstring getDiskModel() {
    return g_diskModel;
}

static uint64_t getDiskCapacityViaWmi() {
    static uint64_t cachedCapacity = 0;
    static bool queried = false;
    if (queried) return cachedCapacity;
    queried = true;

    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    bool comInit = SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;
    if (!comInit) return 0;

    // Try the Win32 DiskDrive class in the cimv2 namespace first
    {
        IWbemLocator* pLocator = nullptr;
        hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER,
            IID_IWbemLocator, (void**)&pLocator);
        if (SUCCEEDED(hr)) {
            IWbemServices* pServices = nullptr;
            hr = pLocator->ConnectServer(
                bstr_t(L"ROOT\\cimv2"),
                nullptr, nullptr, nullptr, 0, nullptr, nullptr, &pServices);
            if (SUCCEEDED(hr)) {
                CoSetProxyBlanket(pServices, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE,
                    nullptr, RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE,
                    nullptr, EOAC_NONE);

                IEnumWbemClassObject* pEnumerator = nullptr;
                hr = pServices->ExecQuery(
                    bstr_t(L"WQL"),
                    bstr_t(L"SELECT Size, Model FROM Win32_DiskDrive WHERE Index=0"),
                    WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                    nullptr, &pEnumerator);

                if (SUCCEEDED(hr)) {
                    IWbemClassObject* pObj = nullptr;
                    ULONG returned = 0;
                    hr = pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &returned);
                    if (SUCCEEDED(hr) && returned > 0) {
                        VARIANT vtSize;
                        VariantInit(&vtSize);
                        hr = pObj->Get(L"Size", 0, &vtSize, nullptr, nullptr);
                        if (SUCCEEDED(hr) && vtSize.vt == VT_BSTR) {
                            cachedCapacity = _wcstoui64(vtSize.bstrVal, nullptr, 10);
                        } else if (SUCCEEDED(hr) && vtSize.vt == VT_UI8) {
                            cachedCapacity = vtSize.ullVal;
                        } else if (SUCCEEDED(hr) && vtSize.vt == VT_I4) {
                            cachedCapacity = (uint64_t)vtSize.intVal;
                        }
                        VariantClear(&vtSize);

                        // Model name from the same drive object, for example SAMSUNG SSD PM871
                        VARIANT vtModel;
                        VariantInit(&vtModel);
                        if (SUCCEEDED(pObj->Get(L"Model", 0, &vtModel, nullptr, nullptr)) && vtModel.vt == VT_BSTR) {
                            g_diskModel = vtModel.bstrVal;
                        }
                        VariantClear(&vtModel);

                        pObj->Release();
                    }
                    pEnumerator->Release();
                }
                pServices->Release();
            }
            pLocator->Release();
        }
    }

    // Fallback to the MSFT Disk class in the storage namespace
    if (cachedCapacity == 0) {
        IWbemLocator* pLocator = nullptr;
        hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER,
            IID_IWbemLocator, (void**)&pLocator);
        if (SUCCEEDED(hr)) {
            IWbemServices* pServices = nullptr;
            hr = pLocator->ConnectServer(
                bstr_t(L"ROOT\\microsoft\\windows\\storage"),
                nullptr, nullptr, nullptr, 0, nullptr, nullptr, &pServices);
            if (SUCCEEDED(hr)) {
                CoSetProxyBlanket(pServices, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE,
                    nullptr, RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE,
                    nullptr, EOAC_NONE);

                IEnumWbemClassObject* pEnumerator = nullptr;
                hr = pServices->ExecQuery(
                    bstr_t(L"WQL"),
                    bstr_t(L"SELECT Size FROM MSFT_Disk WHERE Number=0"),
                    WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                    nullptr, &pEnumerator);

                if (SUCCEEDED(hr)) {
                    IWbemClassObject* pObj = nullptr;
                    ULONG returned = 0;
                    hr = pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &returned);
                    if (SUCCEEDED(hr) && returned > 0) {
                        VARIANT vtSize;
                        VariantInit(&vtSize);
                        hr = pObj->Get(L"Size", 0, &vtSize, nullptr, nullptr);
                        if (SUCCEEDED(hr) && vtSize.vt == VT_BSTR) {
                            cachedCapacity = _wcstoui64(vtSize.bstrVal, nullptr, 10);
                        } else if (SUCCEEDED(hr) && vtSize.vt == VT_UI8) {
                            cachedCapacity = vtSize.ullVal;
                        } else if (SUCCEEDED(hr) && vtSize.vt == VT_I4) {
                            cachedCapacity = (uint64_t)vtSize.intVal;
                        }
                        VariantClear(&vtSize);
                        pObj->Release();
                    }
                    pEnumerator->Release();
                }
                pServices->Release();
            }
            pLocator->Release();
        }
    }

    CoUninitialize();
    return cachedCapacity;
}

// populateDiskInfo gets disk active percent, response time, capacity, type, system disk, and page file info

void populateDiskInfo(SystemStats& stats) {
    initDiskPdh();

    // PDH counters for disk active percent and average response time
    if (g_diskQuery) {
        PDH_FMT_COUNTERVALUE fmtVal;

        if (g_diskActivePct &&
            PdhGetFormattedCounterValue(g_diskActivePct, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS) {
            stats.diskActivePercent = fmtVal.doubleValue;
        }
        if (g_diskAvgTransfer &&
            PdhGetFormattedCounterValue(g_diskAvgTransfer, PDH_FMT_DOUBLE, nullptr, &fmtVal) == ERROR_SUCCESS) {
            stats.diskAvgResponseMs = fmtVal.doubleValue * 1000.0;
        }
    }

    // System drive letter
    WCHAR windowsDir[MAX_PATH];
    GetWindowsDirectoryW(windowsDir, MAX_PATH);
    WCHAR systemDrive = windowsDir[0];

    // Disk capacity via WMI, the full physical disk size including all partitions
    uint64_t wmiCapacity = getDiskCapacityViaWmi();
    if (wmiCapacity > 0) {
        stats.diskCapacityBytes = wmiCapacity;
    } else {        // Fallback to volume size, which only counts a single partition
        WCHAR rootPath[4] = { systemDrive, L':', L'\\', L'\0' };
        ULARGE_INTEGER freeBytesAvailable, totalBytes, totalFreeBytes;
        if (GetDiskFreeSpaceExW(rootPath, &freeBytesAvailable, &totalBytes, &totalFreeBytes)) {
            stats.diskCapacityBytes = totalBytes.QuadPart;
        }
    }

    // Disk model captured from the same WMI query
    stats.diskModel = getDiskModel();

    // Disk type comes from WMI first without admin rights, falling back to the physical drive with admin rights
    if (stats.diskType.empty()) {
        std::wstring wmiType = getDiskTypeViaWmi();
        if (!wmiType.empty()) {
            stats.diskType = wmiType;
        } else {
            for (int i = 0; i < 8; i++) {
                WCHAR drivePath[32];
                swprintf_s(drivePath, L"\\\\.\\PhysicalDrive%d", i);
                HANDLE hDrive = CreateFileW(drivePath, GENERIC_READ,
                    FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
                if (hDrive == INVALID_HANDLE_VALUE) continue;

                DEVICE_SEEK_PENALTY_DESCRIPTOR seekPenalty = {};
                STORAGE_PROPERTY_QUERY query = {};
                query.PropertyId = StorageDeviceSeekPenaltyProperty;
                query.QueryType = PropertyStandardQuery;
                DWORD bytesReturned = 0;
                if (DeviceIoControl(hDrive, IOCTL_STORAGE_QUERY_PROPERTY, &query, sizeof(query),
                    &seekPenalty, sizeof(seekPenalty), &bytesReturned, nullptr)) {
                    stats.diskType = seekPenalty.IncursSeekPenalty ? L"HDD" : L"SSD";
                }
                CloseHandle(hDrive);
                break;
            }
        }
    }

    // We always query the system drive, so this is the system disk
    stats.diskIsSystem = true;

    // Page file presence comes from the registry
    HKEY hKey;
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE,
        L"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management",
        0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        DWORD type = 0;
        DWORD size = 0;
        if (RegQueryValueExW(hKey, L"PagingFiles", nullptr, &type, nullptr, &size) == ERROR_SUCCESS && size > sizeof(DWORD)) {
            stats.diskHasPageFile = true;
        }
        RegCloseKey(hKey);
    }
}
