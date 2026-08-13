#pragma once

// SysPie Disk Stats Header
// Queries system wide and per process disk I O statistics.
// Per process stats are computed inline in the process enumerator file
// using the process disk counters structure from the process extension block.

#include "common/types.h"

// Populates the disk read and write bytes per second values via the PhysicalDisk Total PDH counters.
void getSystemDiskStats(double& readBytesPerSec, double& writeBytesPerSec);

// Populates extended disk info, including capacity, SSD or HDD type, system disk, and page file
void populateDiskInfo(SystemStats& stats);

// Returns the model string of the system disk, captured during the first WMI capacity query
std::wstring getDiskModel();
