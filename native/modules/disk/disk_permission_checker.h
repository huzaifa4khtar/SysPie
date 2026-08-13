#pragma once

// SysPie Disk Permission Checker
// Checks what file access rights a process's user has on the executable file.
// Uses GetNamedSecurityInfoW and GetEffectiveRightsFromAcl to compute the effective access mask.
// Returns Read or Read and Write based on FILE GENERIC WRITE and FILE WRITE DATA rights.

#include <string>
#include <cstdint>

// Check the disk permission a process's user has on its executable file and return Read or Read and Write.
std::wstring checkDiskPermission(uint32_t pid);
