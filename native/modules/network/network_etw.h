#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
#include <wlanapi.h>
#include <evntrace.h>
#include <evntcons.h>
#include <unordered_map>
#include <mutex>
#include <thread>
#include <atomic>
#include <cstdint>

// GUID of the kernel network provider.
extern const GUID GUID_MicrosoftWindowsKernelNetwork;

// ETW event user data structs. The layouts come from the Windows ntwmi header.
#pragma pack(push, 1)

struct WMI_TCPIP_V4 {
    ULONG ProcessId;
    ULONG TransferSize;
    UCHAR DestinationAddress[4];
    UCHAR SourceAddress[4];
    USHORT DestinationPort;
    USHORT SourcePort;
};

struct WMI_TCPIP_V6 {
    ULONG ProcessId;
    ULONG TransferSize;
    UCHAR DestinationAddress[16];
    UCHAR SourceAddress[16];
    USHORT DestinationPort;
    USHORT SourcePort;
};

struct WMI_UDP_V4 {
    ULONG ProcessId;
    USHORT TransferSize;
    UCHAR DestinationAddress[4];
    UCHAR SourceAddress[4];
    USHORT DestinationPort;
    USHORT SourcePort;
};

struct WMI_UDP_V6 {
    ULONG ProcessId;
    USHORT TransferSize;
    UCHAR DestinationAddress[16];
    UCHAR SourceAddress[16];
    USHORT DestinationPort;
    USHORT SourcePort;
};

#pragma pack(pop)

// Tracks accumulated send and receive bytes for one process.
struct NetStats {
    ULONGLONG sendBytes = 0;
    ULONGLONG recvBytes = 0;

    ULONGLONG totalBytes() const { return sendBytes + recvBytes; }
};

// Monitors per process network IO by consuming kernel ETW events on a
// dedicated thread, then returns safe snapshots per PID.
class NetworkEtwMonitor {
public:
    NetworkEtwMonitor() = default;
    ~NetworkEtwMonitor();

    NetworkEtwMonitor(const NetworkEtwMonitor&) = delete;
    NetworkEtwMonitor& operator=(const NetworkEtwMonitor&) = delete;

    bool start();
    void stop();

    // Returns the accumulated bytes per PID held under a lock.
    std::unordered_map<DWORD, NetStats> snapshot();

private:
    static void NTAPI eventRecordCallback(PEVENT_RECORD event);
    static ULONG NTAPI bufferCallback(PEVENT_TRACE_LOGFILEW log);

    void processEvent(PEVENT_RECORD event);
    void traceThreadProc();

    TRACEHANDLE session_handle_ = 0;
    PROCESSTRACE_HANDLE trace_handle_ = INVALID_PROCESSTRACE_HANDLE;
    std::thread trace_thread_;
    std::atomic<bool> running_{false};

    mutable std::mutex mutex_;
    std::unordered_map<DWORD, NetStats> net_bytes_;
    std::atomic<uint64_t> event_count_{0};

    static constexpr LPCWSTR kSessionName = L"SysPieNetMon";
};

extern NetworkEtwMonitor g_networkMonitor;

// Forward declaration.
struct SystemStats;

// Gathers the adapter name, SSID, IP addresses, connection type and signal strength.
void populateNetworkInfo(SystemStats& stats);

// Measures aggregate send and receive bytes per second over the network.
void getNetworkSpeedStats(double& sendBytesPerSec, double& recvBytesPerSec);