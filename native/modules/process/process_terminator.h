#pragma once

// Terminates processes using the native open and terminate calls, ported from System Informer.
#include <cstdint>
#include <string>
#include <vector>

// Terminates a single process by PID, returning true on success or when it was already terminating.
bool terminateProcess(uint32_t pid);

// Terminates a process and all of its descendants, returning true if the target process was terminated.
bool terminateProcessTree(uint32_t pid);

// Terminates several processes and returns how many of them succeeded.
int terminateProcesses(const std::vector<uint32_t>& pids);

// Checks if a process is a known critical system process whose termination could destabilize the system.
bool isDangerousProcess(uint32_t pid);

// Returns the display name of a dangerous process for a warning message, or an empty string when it is safe.
std::wstring getDangerousProcessName(uint32_t pid);
