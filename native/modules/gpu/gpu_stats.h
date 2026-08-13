#pragma once

#include <cstdint>
#include "common/types.h"

// Initialize GPU monitoring (queries adapter info via DXGI, etc.)
bool gpuInit();

// Get the GPU usage percentage for a process using an externally provided elapsed time in 100ns units.
// Call gpuGetElapsed100ns once per refresh before the per process loop.
double gpuGetProcessUsageWithElapsed(uint32_t pid, unsigned long long elapsed100ns);

// Get total GPU usage percentage across all processes.
double gpuGetTotalUsage();

// Returns elapsed time in 100ns units since the last call. Call once per refresh cycle before the per process GPU loop.
unsigned long long gpuGetElapsed100ns();

// Populate GPU info fields in SystemStats (memory, driver version, etc.)
void populateGpuInfo(SystemStats& stats);
