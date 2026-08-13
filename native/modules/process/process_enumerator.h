#pragma once

// Enumerates running processes using NtQuerySystemInformation, ported from System Informer.
#include <vector>
#include <string>
#include <unordered_map>
#include "common/types.h"

// Enumerates all running processes and returns structured data.
std::vector<ProcessInfo> enumerateProcesses();

// Gets the system wide process, thread, and handle counts.
void getProcessSystemCounts(uint32_t& totalProcesses, uint32_t& totalThreads, uint32_t& totalHandles);
