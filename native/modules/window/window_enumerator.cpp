#include "window/window_enumerator.h"
#include <windows.h>
#include <vector>
#include <string>

// Collects the window entries that pass the visibility checks
struct EnumContext {
    std::vector<WindowGroupEntry> results;
};

static std::wstring getWindowTitle(HWND hwnd) {
    // Prefer the caption returned by GetWindowTextW
    int titleLen = GetWindowTextLengthW(hwnd);
    if (titleLen <= 0) return L"";

    std::wstring title(static_cast<size_t>(titleLen) + 1, L'\0');
    titleLen = GetWindowTextW(hwnd, &title[0], static_cast<int>(title.size()));
    if (titleLen <= 0) return L"";
    title.resize(static_cast<size_t>(titleLen));

    // Explorer may report its app name instead of the folder, so ask for the title text directly.
    if (title == L"File Explorer" || title.empty()) {
        UINT msgLen = static_cast<UINT>(SendMessageW(hwnd, WM_GETTEXTLENGTH, 0, 0));
        if (msgLen > 0) {
            std::wstring msgTitle(static_cast<size_t>(msgLen) + 1, L'\0');
            SendMessageW(hwnd, WM_GETTEXT, static_cast<WPARAM>(msgTitle.size()),
                         reinterpret_cast<LPARAM>(&msgTitle[0]));
            msgTitle.resize(wcslen(msgTitle.c_str()));
            if (!msgTitle.empty() && msgTitle != L"File Explorer") {
                return msgTitle;
            }
        }
    }

    return title;
}

static BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
    auto* ctx = reinterpret_cast<EnumContext*>(lParam);

    // Keep only visible windows
    if (!IsWindowVisible(hwnd)) return TRUE;

    // Exclude helper windows without a caption and tool windows without a taskbar entry
    LONG style = GetWindowLongW(hwnd, GWL_STYLE);
    LONG exStyle = GetWindowLongW(hwnd, GWL_EXSTYLE);

    if (!(style & WS_CAPTION)) return TRUE;

    if (exStyle & WS_EX_TOOLWINDOW) return TRUE;

    // Keep only windows with a non empty title
    std::wstring title = getWindowTitle(hwnd);
    if (title.empty()) return TRUE;

    // Skip the desktop window known as Program Manager
    if (title == L"Program Manager") return TRUE;

    // Find the process that owns this window
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == 0) return TRUE;

    WindowGroupEntry entry;
    entry.pid = static_cast<uint32_t>(pid);
    entry.hwnd = reinterpret_cast<uint64_t>(hwnd);
    entry.title = std::move(title);
    ctx->results.push_back(std::move(entry));

    return TRUE;
}

std::vector<WindowGroupEntry> enumerateWindows() {
    EnumContext ctx;
    EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(&ctx));
    return ctx.results;
}
