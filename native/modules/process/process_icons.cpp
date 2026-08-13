#include "process/process_icons.h"
#include <windows.h>
#include <shellapi.h>
#include <gdiplus.h>
#include <psapi.h>
#include <appmodel.h>
#include <mutex>
#include <vector>
#include <unordered_map>
#include <string>

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "shell32.lib")

using namespace Gdiplus;

static ULONG_PTR g_gdiplusToken = 0;
static std::mutex g_iconMutex;
static std::unordered_map<uint32_t, std::string> g_iconCache;

static const char kBase64Chars[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static std::string base64Encode(const std::vector<BYTE>& data) {
    std::string out;
    out.reserve(((data.size() + 2) / 3) * 4);
    for (size_t i = 0; i < data.size(); i += 3) {
        int b = (data[i] << 16)
              | ((i + 1 < data.size() ? data[i + 1] : 0) << 8)
              | (i + 2 < data.size() ? data[i + 2] : 0);
        out += kBase64Chars[(b >> 18) & 0x3F];
        out += kBase64Chars[(b >> 12) & 0x3F];
        out += (i + 1 < data.size()) ? kBase64Chars[(b >> 6) & 0x3F] : '=';
        out += (i + 2 < data.size()) ? kBase64Chars[b & 0x3F] : '=';
    }
    return out;
}

static std::string iconToBase64Png(HICON hIcon) {
    if (!hIcon) return "";

    Bitmap* bitmap = Bitmap::FromHICON(hIcon);
    if (!bitmap) return "";

    IStream* pStream = NULL;
    if (CreateStreamOnHGlobal(NULL, TRUE, &pStream) != S_OK) {
        delete bitmap;
        return "";
    }

    CLSID clsidPng;
    CLSIDFromString(L"{557CF406-1A04-11D3-9A73-0000F81EF32E}", &clsidPng);
    bitmap->Save(pStream, &clsidPng);

    STATSTG stat = {};
    pStream->Stat(&stat, STATFLAG_NONAME);
    ULONG size = stat.cbSize.LowPart;

    if (size == 0) {
        pStream->Release();
        delete bitmap;
        return "";
    }

    std::vector<BYTE> buffer(size);
    LARGE_INTEGER zero = {};
    pStream->Seek(zero, STREAM_SEEK_SET, NULL);
    pStream->Read(buffer.data(), size, NULL);

    pStream->Release();
    delete bitmap;

    return base64Encode(buffer);
}

static std::wstring getMunPath(const std::wstring& exePath) {
    size_t pos = exePath.find(L"\\System32\\");
    if (pos == std::wstring::npos)
        pos = exePath.find(L"\\SysWOW64\\");
    if (pos != std::wstring::npos) {
        std::wstring filename = exePath.substr(pos + 11);
        return L"C:\\Windows\\SystemResources\\" + filename + L".mun";
    }
    return L"";
}

static bool fileExists(const std::wstring& path) {
    return GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES;
}

static HICON getStockIcon() {
    HICON hIcon = NULL;
    HICON hIconSmall = NULL;

    // Try several icon indices in imageres.dll because they vary by Windows version.
    for (int idx : {11, 3, 1, 0}) {
        UINT count = ExtractIconExW(L"imageres.dll", idx, &hIcon, &hIconSmall, 1);
        if (count > 0 && hIcon) {
            if (hIconSmall) DestroyIcon(hIconSmall);
            return hIcon;
        }
        if (hIcon) DestroyIcon(hIcon);
        if (hIconSmall) DestroyIcon(hIconSmall);
        hIcon = NULL;
        hIconSmall = NULL;
    }

    // Try shell32.dll as a secondary fallback.
    for (int idx : {2, 1, 0}) {
        UINT count = ExtractIconExW(L"shell32.dll", idx, &hIcon, &hIconSmall, 1);
        if (count > 0 && hIcon) {
            if (hIconSmall) DestroyIcon(hIconSmall);
            return hIcon;
        }
        if (hIcon) DestroyIcon(hIcon);
        if (hIconSmall) DestroyIcon(hIconSmall);
        hIcon = NULL;
        hIconSmall = NULL;
    }

    return (HICON)LoadImageW(NULL, MAKEINTRESOURCEW(32512), IMAGE_ICON,
        GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), LR_DEFAULTCOLOR);
}

static std::wstring getProcessPath(uint32_t pid) {
    if (pid == 0 || pid == 4) {
        return L"C:\\Windows\\System32\\ntoskrnl.exe";
    }

    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProcess) return L"";

    WCHAR path[MAX_PATH] = {0};
    DWORD size = MAX_PATH;
    std::wstring result;

    if (QueryFullProcessImageNameW(hProcess, 0, path, &size)) {
        result = path;
    }

    CloseHandle(hProcess);
    return result;
}

bool iconCacheInit() {
    GdiplusStartupInput gdiplusStartupInput;
    return GdiplusStartup(&g_gdiplusToken, &gdiplusStartupInput, NULL) == Ok;
}

void iconCacheShutdown() {
    if (g_gdiplusToken) {
        GdiplusShutdown(g_gdiplusToken);
        g_gdiplusToken = 0;
    }
}

std::string getProcessIconBase64(uint32_t pid) {
    std::lock_guard<std::mutex> lock(g_iconMutex);

    auto it = g_iconCache.find(pid);
    if (it != g_iconCache.end()) return it->second;

    std::wstring path = getProcessPath(pid);

    HICON hIcon = NULL;
    HICON hIconSmall = NULL;

    if (!path.empty()) {
        UINT iconCount = ExtractIconExW(path.c_str(), 0, &hIcon, &hIconSmall, 1);
        if (iconCount > 0 && hIcon) {
            std::string base64 = iconToBase64Png(hIcon);
            DestroyIcon(hIcon);
            if (hIconSmall) DestroyIcon(hIconSmall);

            if (!base64.empty()) {
                std::string dataUri = "data:image/png;base64," + base64;
                g_iconCache[pid] = dataUri;
                return dataUri;
            }
        }
        if (hIcon) DestroyIcon(hIcon);
        if (hIconSmall) DestroyIcon(hIconSmall);

        hIcon = NULL;
        hIconSmall = NULL;

        std::wstring munPath = getMunPath(path);
        if (!munPath.empty() && fileExists(munPath)) {
            iconCount = ExtractIconExW(munPath.c_str(), 0, &hIcon, &hIconSmall, 1);
            if (iconCount > 0 && hIcon) {
                std::string base64 = iconToBase64Png(hIcon);
                DestroyIcon(hIcon);
                if (hIconSmall) DestroyIcon(hIconSmall);

                if (!base64.empty()) {
                    std::string dataUri = "data:image/png;base64," + base64;
                    g_iconCache[pid] = dataUri;
                    return dataUri;
                }
            }
            if (hIcon) DestroyIcon(hIcon);
            if (hIconSmall) DestroyIcon(hIconSmall);
        }
    }

    HICON stockIcon = getStockIcon();
    if (stockIcon) {
        std::string base64 = iconToBase64Png(stockIcon);
        DestroyIcon(stockIcon);

        if (!base64.empty()) {
            std::string dataUri = "data:image/png;base64," + base64;
            g_iconCache[pid] = dataUri;
            return dataUri;
        }
    }

    g_iconCache[pid] = "";
    return "";
}

std::string getFileIconBase64(const std::wstring& filePath) {
    if (filePath.empty()) return "";

    std::lock_guard<std::mutex> lock(g_iconMutex);

    HICON hIcon = NULL;
    HICON hIconSmall = NULL;

    UINT iconCount = ExtractIconExW(filePath.c_str(), 0, &hIcon, &hIconSmall, 1);
    if (iconCount > 0 && hIcon) {
        std::string base64 = iconToBase64Png(hIcon);
        DestroyIcon(hIcon);
        if (hIconSmall) DestroyIcon(hIconSmall);

        if (!base64.empty()) {
            return "data:image/png;base64," + base64;
        }
    }
    if (hIcon) DestroyIcon(hIcon);
    if (hIconSmall) DestroyIcon(hIconSmall);

    // Try the .mun fallback for System32 apps.
    hIcon = NULL;
    hIconSmall = NULL;
    std::wstring munPath = getMunPath(filePath);
    if (!munPath.empty() && fileExists(munPath)) {
        iconCount = ExtractIconExW(munPath.c_str(), 0, &hIcon, &hIconSmall, 1);
        if (iconCount > 0 && hIcon) {
            std::string base64 = iconToBase64Png(hIcon);
            DestroyIcon(hIcon);
            if (hIconSmall) DestroyIcon(hIconSmall);

            if (!base64.empty()) {
                return "data:image/png;base64," + base64;
            }
        }
        if (hIcon) DestroyIcon(hIcon);
        if (hIconSmall) DestroyIcon(hIconSmall);
    }

    // Fall back to the stock icon.
    hIcon = NULL;
    hIconSmall = NULL;
    HICON stockIcon = getStockIcon();
    if (stockIcon) {
        std::string base64 = iconToBase64Png(stockIcon);
        DestroyIcon(stockIcon);

        if (!base64.empty()) {
            return "data:image/png;base64," + base64;
        }
    }

    return "";
}

// Resolves app icons from the AUMID for UWP apps.

static std::unordered_map<std::string, std::string> g_aumidIconCache;

// The package family name is the AUMID with the trailing id after the last underscore removed.
static std::wstring extractPackageFamilyName(const std::string& aumid) {
    size_t lastUnderscore = aumid.rfind('_');
    if (lastUnderscore == std::string::npos || lastUnderscore == 0) return L"";
    std::string famName = aumid.substr(0, lastUnderscore);
    int wLen = MultiByteToWideChar(CP_UTF8, 0, famName.c_str(), -1, nullptr, 0);
    if (wLen <= 0) return L"";
    std::wstring result(wLen - 1, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, famName.c_str(), -1, &result[0], wLen);
    return result;
}

static std::wstring findPackageIconPath(const std::wstring& packagePath) {
    const wchar_t* iconNames[] = {
        L"Assets\\Square44x44Logo.targetsize-24_altform-default.png",
        L"Assets\\Square44x44Logo.targetsize-16_altform-default.png",
        L"Assets\\Square44x44Logo.targetsize-24.png",
        L"Assets\\Square44x44Logo.targetsize-16.png",
        L"Assets\\Square44x44Logo.png",
        L"Assets\\StoreLogo.png",
        L"Assets\\Square150x150Logo.png",
        L"Assets\\Wide310x150Logo.png",
        L"Assets\\LargeTile.scale-100.png",
        L"Assets\\SmallTile.scale-100.png",
    };

    for (const wchar_t* name : iconNames) {
        std::wstring fullPath = packagePath + L"\\" + name;
        if (fileExists(fullPath)) return fullPath;
    }

    std::wstring assetsDir = packagePath + L"\\Assets";
    WIN32_FIND_DATAW fd;
    HANDLE hFind = FindFirstFileW((assetsDir + L"\\*.png").c_str(), &fd);
    if (hFind != INVALID_HANDLE_VALUE) {
        std::wstring first = assetsDir + L"\\" + fd.cFileName;
        FindClose(hFind);
        return first;
    }

    hFind = FindFirstFileW((assetsDir + L"\\*.ico").c_str(), &fd);
    if (hFind != INVALID_HANDLE_VALUE) {
        std::wstring first = assetsDir + L"\\" + fd.cFileName;
        FindClose(hFind);
        return first;
    }

    // Fall back to the package main executable.
    hFind = FindFirstFileW((packagePath + L"\\*.exe").c_str(), &fd);
    if (hFind != INVALID_HANDLE_VALUE) {
        std::wstring exePath = packagePath + L"\\" + fd.cFileName;
        FindClose(hFind);
        return exePath;
    }

    return L"";
}

std::string getAumidIconBase64(const std::string& aumid) {
    if (aumid.empty()) return "";

    {
        std::lock_guard<std::mutex> lock(g_iconMutex);
        auto it = g_aumidIconCache.find(aumid);
        if (it != g_aumidIconCache.end()) return it->second;
    }

    std::wstring familyName = extractPackageFamilyName(aumid);
    if (familyName.empty()) return "";

    // Find packages that belong to the family name.
    UINT32 count = 0;
    UINT32 bufferLength = 0;
    LONG res = GetPackagesByPackageFamily(
        familyName.c_str(), &count, nullptr, &bufferLength, nullptr);
    if (res != ERROR_SUCCESS || count == 0) return "";

    std::vector<PWSTR> fullNames(count);
    std::vector<WCHAR> buffer(bufferLength);
    res = GetPackagesByPackageFamily(
        familyName.c_str(), &count, fullNames.data(), &bufferLength, buffer.data());
    if (res != ERROR_SUCCESS || count == 0) return "";

    // Get the install path of the package.
    UINT32 pathLength = 0;
    res = GetPackagePathByFullName(fullNames[0], &pathLength, nullptr);
    if (res != ERROR_SUCCESS || pathLength == 0) return "";

    std::wstring pkgPath(pathLength, L'\0');
    res = GetPackagePathByFullName(fullNames[0], &pathLength, &pkgPath[0]);
    if (res != ERROR_SUCCESS) return "";
    while (!pkgPath.empty() && pkgPath.back() == L'\0') pkgPath.pop_back();

    // Find an icon file inside the package.
    std::wstring iconPath = findPackageIconPath(pkgPath);
    if (iconPath.empty()) return "";

    // Load the icon, handling ico files directly and everything else through extraction.
    HICON hIcon = NULL;
    HICON hIconSmall = NULL;

    if (iconPath.size() >= 4 &&
        _wcsicmp(iconPath.substr(iconPath.size() - 4).c_str(), L".ico") == 0) {
        hIcon = (HICON)LoadImageW(NULL, iconPath.c_str(), IMAGE_ICON,
            GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), LR_LOADFROMFILE);
        hIconSmall = (HICON)LoadImageW(NULL, iconPath.c_str(), IMAGE_ICON,
            GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_LOADFROMFILE);
    } else {
        UINT iconCount = ExtractIconExW(iconPath.c_str(), 0, &hIcon, &hIconSmall, 1);
        if (iconCount == 0) { hIcon = NULL; hIconSmall = NULL; }
    }

    if (hIcon) {
        std::string base64 = iconToBase64Png(hIcon);
        DestroyIcon(hIcon);
        if (hIconSmall) DestroyIcon(hIconSmall);

        if (!base64.empty()) {
            std::string dataUri = "data:image/png;base64," + base64;
            std::lock_guard<std::mutex> lock(g_iconMutex);
            g_aumidIconCache[aumid] = dataUri;
            return dataUri;
        }
    }
    if (hIcon) DestroyIcon(hIcon);
    if (hIconSmall) DestroyIcon(hIconSmall);

    return "";
}
