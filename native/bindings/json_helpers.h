#pragma once

#include "common/types.h"
#include <string>
#include <vector>
#include <cstdint>

std::string escapeJsonString(const std::wstring& wstr);
std::string jsonValue(double val);
std::string jsonValue(int val);
std::string jsonValue(unsigned int val);
std::string jsonValue(uint64_t val);
std::string jsonValue(bool val);
std::string jsonValue(const std::string& val);
std::string jsonValue(const std::wstring& val);
std::string narrowWide(const std::wstring& ws);
std::string processesToJson(const std::vector<ProcessInfo>& processes);
std::string statsToJson(const SystemStats& stats, uint32_t totalProcesses, uint32_t totalThreads,
                        uint32_t totalHandles, double diskReadBps, double diskWriteBps, double gpuPercent,
                        double netSendBps = 0, double netRecvBps = 0);
std::string processToJson(const ProcessInfo& p);
std::string servicesListToJson(const std::vector<ServiceInfo>& services);
