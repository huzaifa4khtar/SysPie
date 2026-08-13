#include "power/power_estimator.h"

static const char* kVeryLow  = "Very Low";
static const char* kLow      = "Low";
static const char* kModerate = "Moderate";
static const char* kHigh     = "High";
static const char* kVeryHigh = "Very High";

std::string computePowerUsageLabel(double cpuPercent, double gpuPercent, double diskMBps) {
    if (cpuPercent < 0.0) cpuPercent = 0.0;
    if (gpuPercent < 0.0) gpuPercent = 0.0;
    if (diskMBps < 0.0) diskMBps = 0.0;

    double cpuScore = cpuPercent * 0.6;
    double gpuScore = gpuPercent * 0.3;

    double diskScore = 0.0;
    if (diskMBps > 0.0) {
        diskScore = (diskMBps < 50.0) ? (diskMBps / 50.0 * 10.0)  : 10.0;
    }

    double composite = cpuScore + gpuScore + diskScore;

    if (composite >= 65.0) return kVeryHigh;
    if (composite >= 35.0) return kHigh;
    if (composite >= 15.0) return kModerate;
    if (composite >= 5.0)  return kLow;
    return kVeryLow;
}
