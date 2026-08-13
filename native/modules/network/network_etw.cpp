#include "network/network_etw.h"
#include "common/types.h"

#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <vector>

#include <ole2.h>
#include <comdef.h>
#include <Wbemidl.h>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "wlanapi.lib")
#pragma comment(lib, "ws2_32.lib")

// {7DD42A49-5329-4832-8DFD-43D979153A88}
const GUID GUID_MicrosoftWindowsKernelNetwork =
    { 0x7DD42A49, 0x5329, 0x4832, { 0x8D, 0xFD, 0x43, 0xD9, 0x79, 0x15, 0x3A, 0x88 } };

#pragma comment(lib, "advapi32.lib")

// Event IDs for the Microsoft-Windows-Kernel-Network provider, split between TCP and UDP.

// TCP
static constexpr USHORT kEvtTcpIpV4Send = 10;
static constexpr USHORT kEvtTcpIpV4Recv = 11;
static constexpr USHORT kEvtTcpIpV6Send = 26;
static constexpr USHORT kEvtTcpIpV6Recv = 27;
// UDP
static constexpr USHORT kEvtUdpIpV4Send = 42;
static constexpr USHORT kEvtUdpIpV4Recv = 43;
static constexpr USHORT kEvtUdpIpV6Send = 58;
static constexpr USHORT kEvtUdpIpV6Recv = 59;

static constexpr ULONGLONG kKeywordIpv4 = 0x10;
static constexpr ULONGLONG kKeywordIpv6 = 0x20;

// The instance is stored in the OpenTraceW Context so the static callback can route events to the right monitor without a global singleton.

void NTAPI NetworkEtwMonitor::eventRecordCallback(PEVENT_RECORD event) {
    auto self = static_cast<NetworkEtwMonitor*>(event->UserContext);
    if (self) {
        self->processEvent(event);
    }
}

ULONG NTAPI NetworkEtwMonitor::bufferCallback(PEVENT_TRACE_LOGFILEW /*log*/) {
    return TRUE;
}

// Decode one ETW event and add its byte count to the right PID.

void NetworkEtwMonitor::processEvent(PEVENT_RECORD event) {
    // Only handle events from our kernel network provider.
    if (!IsEqualGUID(event->EventHeader.ProviderId, GUID_MicrosoftWindowsKernelNetwork)) {
        return;
    }

    USHORT eventId = event->EventHeader.EventDescriptor.Id;
    PVOID userData = event->UserData;
    ULONG userDataLen = event->UserDataLength;

    DWORD pid = 0;
    ULONG byteCount = 0;
    bool isSend = true;

    switch (eventId) {
    case kEvtTcpIpV4Send:
        isSend = true;
        if (userDataLen >= sizeof(WMI_TCPIP_V4)) {
            auto d = static_cast<WMI_TCPIP_V4*>(userData);
            pid = d->ProcessId;
            byteCount = d->TransferSize;
        }
        break;

    case kEvtTcpIpV4Recv:
        isSend = false;
        if (userDataLen >= sizeof(WMI_TCPIP_V4)) {
            auto d = static_cast<WMI_TCPIP_V4*>(userData);
            pid = d->ProcessId;
            byteCount = d->TransferSize;
        }
        break;

    case kEvtTcpIpV6Send:
        isSend = true;
        if (userDataLen >= sizeof(WMI_TCPIP_V6)) {
            auto d = static_cast<WMI_TCPIP_V6*>(userData);
            pid = d->ProcessId;
            byteCount = d->TransferSize;
        }
        break;

    case kEvtTcpIpV6Recv:
        isSend = false;
        if (userDataLen >= sizeof(WMI_TCPIP_V6)) {
            auto d = static_cast<WMI_TCPIP_V6*>(userData);
            pid = d->ProcessId;
            byteCount = d->TransferSize;
        }
        break;

    case kEvtUdpIpV4Send:
        isSend = true;
        if (userDataLen >= sizeof(WMI_UDP_V4)) {
            auto d = static_cast<WMI_UDP_V4*>(userData);
            pid = d->ProcessId;
            byteCount = d->TransferSize;
        }
        break;

    case kEvtUdpIpV4Recv:
        isSend = false;
        if (userDataLen >= sizeof(WMI_UDP_V4)) {
            auto d = static_cast<WMI_UDP_V4*>(userData);
            pid = d->ProcessId;
            byteCount = d->TransferSize;
        }
        break;

    case kEvtUdpIpV6Send:
        isSend = true;
        if (userDataLen >= sizeof(WMI_UDP_V6)) {
            auto d = static_cast<WMI_UDP_V6*>(userData);
            pid = d->ProcessId;
            byteCount = d->TransferSize;
        }
        break;

    case kEvtUdpIpV6Recv:
        isSend = false;
        if (userDataLen >= sizeof(WMI_UDP_V6)) {
            auto d = static_cast<WMI_UDP_V6*>(userData);
            pid = d->ProcessId;
            byteCount = d->TransferSize;
        }
        break;

    default:
        return;
    }

    if (pid == 0 || byteCount == 0) return;

    // Add the bytes to the per process totals under a short lock.
    std::lock_guard<std::mutex> lock(mutex_);
    NetStats& stats = net_bytes_[pid];
    if (isSend) {
        stats.sendBytes += byteCount;
    } else {
        stats.recvBytes += byteCount;
    }
    event_count_++;
}

// The thread that blocks on ProcessTrace.

void NetworkEtwMonitor::traceThreadProc() {
    PROCESSTRACE_HANDLE handles[] = { trace_handle_ };

    // Use a raw timestamp to skip conversion overhead.
    ULONG status = ProcessTrace(handles, 1, nullptr, nullptr);

    if (status != ERROR_SUCCESS && status != ERROR_CTX_CLOSE_PENDING) {
        fprintf(stderr, "[NetworkEtw] ProcessTrace returned 0x%lx\n", status);
    }
}

// Stop a trace session by name. The properties buffer must be heap allocated with room for the session name.

static void StopTraceSession(LPCWSTR name) {
    ULONG size = sizeof(EVENT_TRACE_PROPERTIES) + 256;
    EVENT_TRACE_PROPERTIES* p = (EVENT_TRACE_PROPERTIES*)calloc(1, size);
    if (!p) return;
    p->Wnode.BufferSize = size;
    p->LoggerNameOffset = sizeof(EVENT_TRACE_PROPERTIES);
    wcscpy_s((wchar_t*)((BYTE*)p + p->LoggerNameOffset),
             (size - sizeof(EVENT_TRACE_PROPERTIES)) / sizeof(wchar_t),
             name);
    ControlTraceW(0, name, p, EVENT_TRACE_CONTROL_STOP);
    free(p);
}

// Start the ETW session and begin collecting network events.

bool NetworkEtwMonitor::start() {
    if (running_.exchange(true)) {
        fprintf(stderr, "[NetworkEtw] Start() called but already running.\n");
        return false;
    }

    fprintf(stderr, "[NetworkEtw] Starting ETW session '%ls'...\n", kSessionName);

    // Kernel ETW sessions require the system profile privilege, so enable it.
    {
        HANDLE hToken = NULL;
        if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
            TOKEN_PRIVILEGES tp;
            tp.PrivilegeCount = 1;
            tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
            if (LookupPrivilegeValueA(NULL, "SeSystemProfilePrivilege", &tp.Privileges[0].Luid)) {
                if (AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), NULL, NULL)) {
                    DWORD err = GetLastError();
                    if (err == 0) {
                        fprintf(stderr, "[NetworkEtw] SeSystemProfilePrivilege enabled successfully.\n");
                    } else {
                        fprintf(stderr, "[NetworkEtw] AdjustTokenPrivileges partial: GetLastError=%lu\n", err);
                    }
                } else {
                    fprintf(stderr, "[NetworkEtw] AdjustTokenPrivileges failed: %lu\n", GetLastError());
                }
            } else {
                fprintf(stderr, "[NetworkEtw] LookupPrivilegeValue failed: %lu\n", GetLastError());
            }
            CloseHandle(hToken);
        } else {
            fprintf(stderr, "[NetworkEtw] OpenProcessToken failed: %lu\n", GetLastError());
        }
    }

    // Allocate and configure the trace properties.
    ULONG propsSize = sizeof(EVENT_TRACE_PROPERTIES) + 256;
    EVENT_TRACE_PROPERTIES* props = (EVENT_TRACE_PROPERTIES*)calloc(1, propsSize);
    if (!props) { running_ = false; fprintf(stderr, "[NetworkEtw] Failed to allocate props.\n"); return false; }

    props->Wnode.BufferSize = propsSize;
    props->Wnode.Flags = WNODE_FLAG_TRACED_GUID;
    props->LogFileMode = EVENT_TRACE_REAL_TIME_MODE;
    props->MinimumBuffers = 8;
    props->MaximumBuffers = 64;
    props->BufferSize = 64;
    props->LoggerNameOffset = sizeof(EVENT_TRACE_PROPERTIES);
    wcscpy_s((wchar_t*)((BYTE*)props + props->LoggerNameOffset),
             (propsSize - props->LoggerNameOffset) / sizeof(wchar_t),
             kSessionName);

    // Start the trace session.
    ULONG status = StartTraceW(&session_handle_, kSessionName, props);
    fprintf(stderr, "[NetworkEtw] StartTraceW returned %lu (0x%lx)\n", status, status);

    free(props);

    if (status == ERROR_ALREADY_EXISTS) {
        fprintf(stderr, "[NetworkEtw] Session already exists, stopping and retrying...\n");
        StopTraceSession(kSessionName);
        EVENT_TRACE_PROPERTIES* p2 = (EVENT_TRACE_PROPERTIES*)calloc(1, propsSize);
        if (p2) {
            p2->Wnode.BufferSize = propsSize;
            p2->Wnode.Flags = WNODE_FLAG_TRACED_GUID;
            p2->LogFileMode = EVENT_TRACE_REAL_TIME_MODE;
            p2->MinimumBuffers = 8;
            p2->MaximumBuffers = 64;
            p2->BufferSize = 64;
            p2->LoggerNameOffset = sizeof(EVENT_TRACE_PROPERTIES);
            wcscpy_s((wchar_t*)((BYTE*)p2 + p2->LoggerNameOffset),
                     (propsSize - sizeof(EVENT_TRACE_PROPERTIES)) / sizeof(wchar_t),
                     kSessionName);
            status = StartTraceW(&session_handle_, kSessionName, p2);
            fprintf(stderr, "[NetworkEtw] Retry StartTraceW returned %lu (0x%lx)\n", status, status);
            free(p2);
        } else {
            running_ = false;
            return false;
        }
    }

    if (status != ERROR_SUCCESS) {
        fprintf(stderr, "[NetworkEtw] StartTraceW failed: %lu. Requires admin/SeSystemProfilePrivilege.\n", status);
        session_handle_ = 0;
        running_ = false;
        return false;
    }

    // Enable the provider with a filter on the event IDs we want.
    USHORT filterEventIds[] = {
        kEvtTcpIpV4Send,
        kEvtTcpIpV4Recv,
        kEvtTcpIpV6Send,
        kEvtTcpIpV6Recv,
        kEvtUdpIpV4Send,
        kEvtUdpIpV4Recv,
        kEvtUdpIpV6Send,
        kEvtUdpIpV6Recv,
    };
    size_t filterDataSize = FIELD_OFFSET(EVENT_FILTER_EVENT_ID, Events) + sizeof(filterEventIds);
    PEVENT_FILTER_EVENT_ID pFilterData = (PEVENT_FILTER_EVENT_ID)malloc(filterDataSize);
    if (!pFilterData) return false;
    pFilterData->FilterIn = TRUE;
    pFilterData->Count = ARRAYSIZE(filterEventIds);
    memcpy(pFilterData->Events, filterEventIds, sizeof(filterEventIds));

    EVENT_FILTER_DESCRIPTOR filterDesc = {};
    filterDesc.Ptr = (ULONGLONG)(ULONG_PTR)pFilterData;
    filterDesc.Size = (USHORT)filterDataSize;
    filterDesc.Type = EVENT_FILTER_TYPE_EVENT_ID;

    ENABLE_TRACE_PARAMETERS enableParams = {};
    enableParams.Version = ENABLE_TRACE_PARAMETERS_VERSION_2;
    enableParams.EnableFilterDesc = &filterDesc;
    enableParams.FilterDescCount = 1;

    status = EnableTraceEx2(
        session_handle_,
        &GUID_MicrosoftWindowsKernelNetwork,
        EVENT_CONTROL_CODE_ENABLE_PROVIDER,
        TRACE_LEVEL_INFORMATION,
        kKeywordIpv4 | kKeywordIpv6,
        0,
        INFINITE,
        &enableParams);

    if (status != ERROR_SUCCESS) {
        fprintf(stderr, "[NetworkEtw] EnableTraceEx2 failed: %lu (0x%lx)\n", status, status);
        free(pFilterData);
        StopTraceSession(kSessionName);
        session_handle_ = 0;
        running_ = false;
        return false;
    }
    fprintf(stderr, "[NetworkEtw] Provider enabled successfully.\n");

    free(pFilterData);

    // Open the trace for consumption.
    EVENT_TRACE_LOGFILEW logFile = {};
    logFile.LoggerName = const_cast<LPWSTR>(kSessionName);
    logFile.ProcessTraceMode = PROCESS_TRACE_MODE_REAL_TIME |
                               PROCESS_TRACE_MODE_EVENT_RECORD;
    logFile.EventRecordCallback = eventRecordCallback;
    logFile.BufferCallback = bufferCallback;
    logFile.Context = this;

    trace_handle_ = OpenTraceW(&logFile);
    if (trace_handle_ == INVALID_PROCESSTRACE_HANDLE) {
        fprintf(stderr, "[NetworkEtw] OpenTraceW failed. GetLastError=%lu\n", GetLastError());
        StopTraceSession(kSessionName);
        session_handle_ = 0;
        running_ = false;
        return false;
    }

    // Start the consumer thread.
    trace_thread_ = std::thread(&NetworkEtwMonitor::traceThreadProc, this);

    fprintf(stderr, "[NetworkEtw] Session started, provider enabled with %d event IDs.\n",
            (int)ARRAYSIZE(filterEventIds));
    return true;
}

// Stop the ETW session and wait for the consumer thread.

void NetworkEtwMonitor::stop() {
    if (!running_.exchange(false)) return;

    // Closing the trace makes ProcessTrace return with a close pending result.
    if (trace_handle_ != INVALID_PROCESSTRACE_HANDLE) {
        CloseTrace(trace_handle_);
        trace_handle_ = INVALID_PROCESSTRACE_HANDLE;
    }

    // Wait for the trace thread to finish.
    if (trace_thread_.joinable()) {
        trace_thread_.join();
    }

    // Stop the session.
    if (session_handle_) {
        StopTraceSession(kSessionName);
        session_handle_ = 0;
    }
}



// Returns the collected bytes while holding the lock.
std::unordered_map<DWORD, NetStats> NetworkEtwMonitor::snapshot() {
    std::lock_guard<std::mutex> lock(mutex_);
    return net_bytes_;
}

NetworkEtwMonitor::~NetworkEtwMonitor() {
    stop();
}

// Global instance
NetworkEtwMonitor g_networkMonitor;

// Measures the active adapter speed with GetIfEntry2, the same approach System Informer uses.
static IF_LUID g_activeAdapterLuid = {};
static bool g_adapterLuidFound = false;
static uint64_t g_prevInOctets = 0;
static uint64_t g_prevOutOctets = 0;
static uint64_t g_prevNetTick = 0;
static bool g_netFirstSample = true;

void getNetworkSpeedStats(double& sendBytesPerSec, double& recvBytesPerSec) {
    sendBytesPerSec = 0.0;
    recvBytesPerSec = 0.0;

    if (!g_adapterLuidFound) return;

    MIB_IF_ROW2 row = {};
    row.InterfaceLuid = g_activeAdapterLuid;
    if (GetIfEntry2(&row) != NO_ERROR) return;

    uint64_t now = GetTickCount64();

    if (g_netFirstSample) {
        g_prevInOctets = row.InOctets;
        g_prevOutOctets = row.OutOctets;
        g_prevNetTick = now;
        g_netFirstSample = false;
        return;
    }

    uint64_t elapsed = now - g_prevNetTick;
    if (elapsed == 0) return;

    uint64_t deltaIn = row.InOctets - g_prevInOctets;
    uint64_t deltaOut = row.OutOctets - g_prevOutOctets;

    sendBytesPerSec = (double)deltaOut * 1000.0 / elapsed;
    recvBytesPerSec = (double)deltaIn * 1000.0 / elapsed;

    g_prevInOctets = row.InOctets;
    g_prevOutOctets = row.OutOctets;
    g_prevNetTick = now;
}

void populateNetworkInfo(SystemStats& stats) {
    // Get active network adapter info
    ULONG outBufLen = 15000;
    std::vector<BYTE> buffer(outBufLen);
    PIP_ADAPTER_ADDRESSES adapters = (PIP_ADAPTER_ADDRESSES)buffer.data();

    if (GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr,
        adapters, &outBufLen) == NO_ERROR) {
        for (auto* adapter = adapters; adapter; adapter = adapter->Next) {
            if (adapter->OperStatus == IfOperStatusUp) {
                if (adapter->IfType == IF_TYPE_IEEE80211 || adapter->IfType == IF_TYPE_ETHERNET_CSMACD) {
                    stats.netAdapterName = adapter->FriendlyName;
                    if (adapter->Description && wcslen(adapter->Description) > 0) {
                        stats.netNicModel = adapter->Description;
                    }

                    // Remember the adapter for later speed queries.
                    if (!g_adapterLuidFound) {
                        g_activeAdapterLuid = adapter->Luid;
                        g_adapterLuidFound = true;
                    }

                    for (auto* ua = adapter->FirstUnicastAddress; ua; ua = ua->Next) {
                        if (ua->Address.lpSockaddr->sa_family == AF_INET) {
                            char ip[INET_ADDRSTRLEN];
                            inet_ntop(AF_INET, &((sockaddr_in*)ua->Address.lpSockaddr)->sin_addr,
                                ip, sizeof(ip));
                            int len = MultiByteToWideChar(CP_UTF8, 0, ip, -1, nullptr, 0);
                            if (len > 0) {
                                stats.netIpv4Address.resize(len - 1);
                                MultiByteToWideChar(CP_UTF8, 0, ip, -1, &stats.netIpv4Address[0], len);
                            }
                        } else if (ua->Address.lpSockaddr->sa_family == AF_INET6) {
                            char ip[INET6_ADDRSTRLEN];
                            inet_ntop(AF_INET6, &((sockaddr_in6*)ua->Address.lpSockaddr)->sin6_addr,
                                ip, sizeof(ip));
                            std::string ipv6(ip);
                            ipv6 += "%" + std::to_string(adapter->Ipv6IfIndex);
                            int len = MultiByteToWideChar(CP_UTF8, 0, ipv6.c_str(), -1, nullptr, 0);
                            if (len > 0) {
                                stats.netIpv6Address.resize(len - 1);
                                MultiByteToWideChar(CP_UTF8, 0, ipv6.c_str(), -1, &stats.netIpv6Address[0], len);
                            }
                        }
                    }

                    if (!stats.netAdapterName.empty()) break;
                }
            }
        }
    }

    // WiFi-specific info via WLAN API
    HANDLE wlanHandle = nullptr;
    DWORD dwMaxClient = 2;
    DWORD dwCurVersion = 0;
    DWORD dwResult = WlanOpenHandle(dwMaxClient, nullptr, &dwCurVersion, &wlanHandle);
    if (dwResult == ERROR_SUCCESS) {
        WLAN_INTERFACE_INFO_LIST* interfaceList = nullptr;
        dwResult = WlanEnumInterfaces(wlanHandle, nullptr, &interfaceList);
        if (dwResult == ERROR_SUCCESS && interfaceList) {
            for (DWORD i = 0; i < interfaceList->dwNumberOfItems; i++) {
                WLAN_CONNECTION_ATTRIBUTES* pConnInfo = nullptr;
                DWORD connInfoSize = 0;
                dwResult = WlanQueryInterface(wlanHandle,
                    &interfaceList->InterfaceInfo[i].InterfaceGuid,
                    wlan_intf_opcode_current_connection,
                    nullptr, &connInfoSize, (PVOID*)&pConnInfo, nullptr);
                if (dwResult == ERROR_SUCCESS && pConnInfo) {
                    auto& ssid = pConnInfo->wlanAssociationAttributes.dot11Ssid;
                    if (ssid.uSSIDLength > 0) {
                        stats.netSsid = std::wstring(ssid.ucSSID, ssid.ucSSID + ssid.uSSIDLength);
                    }
                    stats.netSignalPercent = pConnInfo->wlanAssociationAttributes.wlanSignalQuality;
                    switch (pConnInfo->wlanAssociationAttributes.dot11PhyType) {
                        case dot11_phy_type_ofdm: stats.netConnectionType = L"802.11a"; break;
                        case dot11_phy_type_dsss: stats.netConnectionType = L"802.11b"; break;
                        case dot11_phy_type_erp: stats.netConnectionType = L"802.11g"; break;
                        case dot11_phy_type_ht: stats.netConnectionType = L"802.11n"; break;
                        case dot11_phy_type_vht: stats.netConnectionType = L"802.11ac"; break;
                        case dot11_phy_type_he: stats.netConnectionType = L"802.11ax"; break;
                        case dot11_phy_type_eht: stats.netConnectionType = L"802.11be"; break;
                        default: stats.netConnectionType = L"WiFi"; break;
                    }
                    WlanFreeMemory(pConnInfo);
                    break;
                }
                if (pConnInfo) WlanFreeMemory(pConnInfo);
            }
            WlanFreeMemory(interfaceList);
        }
        WlanCloseHandle(wlanHandle, nullptr);
    }

    // WMI fallback for SSID and signal strength if WLAN API didn't provide them
    if (stats.netSsid.empty() || stats.netSignalPercent == 0) {
        HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        bool comInit = SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;
        if (comInit) {
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

                    // Read the SSID from WMI when the WLAN API left it empty.
                    if (stats.netSsid.empty()) {
                        IEnumWbemClassObject* pEnumerator = nullptr;
                        hr = pServices->ExecQuery(
                            bstr_t(L"WQL"),
                            bstr_t(L"SELECT SSID FROM WiFi_AdapterAssociationInfo WHERE Associated = TRUE"),
                            WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                            nullptr, &pEnumerator);
                        if (SUCCEEDED(hr)) {
                            IWbemClassObject* pObj = nullptr;
                            ULONG returned = 0;
                            hr = pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &returned);
                            if (SUCCEEDED(hr) && returned > 0) {
                                VARIANT vtSSID;
                                VariantInit(&vtSSID);
                                hr = pObj->Get(L"SSID", 0, &vtSSID, nullptr, nullptr);
                                if (SUCCEEDED(hr) && vtSSID.vt == VT_BSTR && SysStringLen(vtSSID.bstrVal) > 0) {
                                    stats.netSsid = vtSSID.bstrVal;
                                }
                                VariantClear(&vtSSID);
                                pObj->Release();
                            }
                            pEnumerator->Release();
                        }
                    }

                    // Read the signal strength from WMI when it is still unset.
                    if (stats.netSignalPercent == 0) {
                        IEnumWbemClassObject* pEnumerator = nullptr;
                        hr = pServices->ExecQuery(
                            bstr_t(L"WQL"),
                            bstr_t(L"SELECT SignalQuality FROM WiFi_AdapterSignalParameters"),
                            WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                            nullptr, &pEnumerator);
                        if (SUCCEEDED(hr)) {
                            IWbemClassObject* pObj = nullptr;
                            ULONG returned = 0;
                            hr = pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &returned);
                            if (SUCCEEDED(hr) && returned > 0) {
                                VARIANT vtSignal;
                                VariantInit(&vtSignal);
                                hr = pObj->Get(L"SignalQuality", 0, &vtSignal, nullptr, nullptr);
                                if (SUCCEEDED(hr) && vtSignal.vt == VT_BSTR) {
                                    stats.netSignalPercent = _wtoi(vtSignal.bstrVal);
                                } else if (SUCCEEDED(hr) && vtSignal.vt == VT_I4) {
                                    stats.netSignalPercent = vtSignal.intVal;
                                }
                                VariantClear(&vtSignal);
                                pObj->Release();
                            }
                            pEnumerator->Release();
                        }
                    }

                    // Last resort reads the raw signal strength from WMI and converts it to a percentage.
                    if (stats.netSignalPercent == 0) {
                        IEnumWbemClassObject* pEnumerator = nullptr;
                        hr = pServices->ExecQuery(
                            bstr_t(L"WQL"),
                            bstr_t(L"SELECT Ndis80211ReceivedSignalStrength FROM MSNdis_80211_ReceivedSignalStrength WHERE Active = TRUE"),
                            WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                            nullptr, &pEnumerator);
                        if (SUCCEEDED(hr)) {
                            IWbemClassObject* pObj = nullptr;
                            ULONG returned = 0;
                            hr = pEnumerator->Next(WBEM_INFINITE, 1, &pObj, &returned);
                            if (SUCCEEDED(hr) && returned > 0) {
                                VARIANT vtRSSI;
                                VariantInit(&vtRSSI);
                                hr = pObj->Get(L"Ndis80211ReceivedSignalStrength", 0, &vtRSSI, nullptr, nullptr);
                                if (SUCCEEDED(hr) && vtRSSI.vt == VT_I4) {
                                    long rssi = vtRSSI.intVal;
                                    if (rssi < -100) rssi = -100;
                                    if (rssi > 0) rssi = 0;
                                    stats.netSignalPercent = (uint32_t)((rssi + 100) * 2);
                                }
                                VariantClear(&vtRSSI);
                                pObj->Release();
                            }
                            pEnumerator->Release();
                        }
                    }

                    pServices->Release();
                }
                pLocator->Release();
            }
            CoUninitialize();
        }
    }
}
