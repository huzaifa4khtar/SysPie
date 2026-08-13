#pragma once

// Lists Windows services through the SCM API and controls them with start, stop, and restart
#include "common/types.h"
#include <string>

// Legacy helper returning one entry per service and pid pair for attaching service host info to processes
std::vector<ServiceHostInfo> enumerateServices();

// Lists every service including stopped ones with full details
std::vector<ServiceInfo> enumerateAllServices();

// Start, stop, and restart actions for a named service
bool startServiceByName(const std::wstring& serviceName);
bool stopServiceByName(const std::wstring& serviceName);
bool restartServiceByName(const std::wstring& serviceName);

// Returns the error from the last service control action, call it right after a failure
unsigned long getLastServiceError();


