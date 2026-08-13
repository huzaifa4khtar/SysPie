#pragma once

#include <cstdint>

// Result of one CPU sampling interval.
// usage  = total busy percent (kernel+user) of all logical processors
// kernel = kernel-only share of the interval
// user   = user-only share of the interval
struct CpuPercentages {
    double usage = 0.0;
    double kernel = 0.0;
    double user = 0.0;
};

// Pure function: converts cumulative NT performance counters for two successive samples
// into the percentages for that interval. A decreasing counter (reset) is treated as zero
// delta. Semantics match DeltaTracker in common/nt_types.h.
inline CpuPercentages computeCpuPercent(
    std::uint64_t prevBusyKernel, std::uint64_t curBusyKernel,
    std::uint64_t prevUser, std::uint64_t curUser,
    std::uint64_t prevIdle, std::uint64_t curIdle) {
    CpuPercentages out;
    const std::uint64_t kernelDelta =
        curBusyKernel >= prevBusyKernel ? curBusyKernel - prevBusyKernel : 0;
    const std::uint64_t userDelta =
        curUser >= prevUser ? curUser - prevUser : 0;
    const std::uint64_t idleDelta =
        curIdle >= prevIdle ? curIdle - prevIdle : 0;
    const std::uint64_t totalDelta = kernelDelta + userDelta + idleDelta;
    if (totalDelta == 0) return out;
    out.usage = (double)(kernelDelta + userDelta) / (double)totalDelta * 100.0;
    out.kernel = (double)kernelDelta / (double)totalDelta * 100.0;
    out.user = (double)userDelta / (double)totalDelta * 100.0;
    return out;
}