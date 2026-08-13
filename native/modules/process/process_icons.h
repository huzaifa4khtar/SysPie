#pragma once

#include <string>
#include <unordered_map>

// Returns the base64 encoded PNG icon for a process, or an empty string when it cannot be extracted.
std::string getProcessIconBase64(uint32_t pid);

// Returns the base64 encoded PNG icon for a file, or an empty string when it cannot be extracted.
std::string getFileIconBase64(const std::wstring& filePath);

// Returns the base64 encoded PNG icon for a packaged app, locating its package by family name, or an empty string on failure.
std::string getAumidIconBase64(const std::string& aumid);

// Initializes the icon cache and starts GDI+.
bool iconCacheInit();

// Shuts down the icon cache and GDI+.
void iconCacheShutdown();
