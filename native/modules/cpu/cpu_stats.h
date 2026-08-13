#pragma once

// SysPie CPU Stats
// Queries system wide CPU usage via NtQuerySystemInformation.

#include "common/types.h"

// Get system wide CPU statistics.
SystemStats getSystemStats();
