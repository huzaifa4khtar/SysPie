#pragma once

#include <string>

// Initialize the GPU Engine PDH counters, and call this before starting the collector.
bool gpuEngineInit();

// Start the background collector thread.
void gpuEngineStartCollector();

// Get the primary, or busiest, GPU engine name for a PID, such as GPU 0 3D, or an empty string if the process has no GPU usage.
std::wstring gpuEngineGetPrimaryEngine(unsigned int pid);
