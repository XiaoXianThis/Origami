#include "window_enum.h"

#include <dwmapi.h>

#include <algorithm>

namespace {

constexpr int kMinWindowWidth = 200;
constexpr int kMinWindowHeight = 120;
constexpr DWORD kTitleTimeoutMs = 40;

std::wstring ClassNameOf(HWND hwnd) {
    wchar_t buffer[256]{};
    GetClassNameW(hwnd, buffer, 256);
    return buffer;
}

bool IsCloaked(HWND hwnd) {
    DWORD cloaked = 0;
    if (SUCCEEDED(DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked)))) {
        return cloaked != 0;
    }
    return false;
}

bool IsManagedWindow(HWND hwnd) {
    if (!IsWindowVisible(hwnd)) {
        return false;
    }
    if (GetWindow(hwnd, GW_OWNER) != nullptr) {
        return false;
    }
    const LONG_PTR ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    if ((ex_style & WS_EX_TOOLWINDOW) != 0) {
        return false;
    }
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == GetCurrentProcessId()) {
        return false;
    }
    if (IsCloaked(hwnd)) {
        return false;
    }
    const std::wstring cls = ClassNameOf(hwnd);
    static const wchar_t* const kDeniedClasses[] = {
        L"Progman",
        L"WorkerW",
        L"Shell_TrayWnd",
        L"Shell_SecondaryTrayWnd",
        L"Windows.UI.Core.CoreWindow",
    };
    for (const wchar_t* denied : kDeniedClasses) {
        if (cls == denied) {
            return false;
        }
    }
    return true;
}

BOOL CALLBACK EnumProc(HWND hwnd, LPARAM param) {
    auto* out = reinterpret_cast<std::vector<WindowInfo>*>(param);
    if (!IsManagedWindow(hwnd)) {
        return TRUE;
    }
    WindowInfo info;
    info.hwnd = hwnd;
    GetWindowThreadProcessId(hwnd, &info.pid);
    // A minimized window reports its icon-sized rect, so the size filter only
    // applies to windows that are actually on screen. Membership in a group must
    // survive minimization, otherwise hiding a window would dissolve its group.
    info.minimized = IsIconic(hwnd) != FALSE;
    info.frame = VisibleFrame(hwnd);
    if (!info.minimized) {
        const int width = info.frame.right - info.frame.left;
        const int height = info.frame.bottom - info.frame.top;
        if (width < kMinWindowWidth || height < kMinWindowHeight) {
            return TRUE;
        }
    }
    out->push_back(info);
    return TRUE;
}

}  // namespace

void EnumerateWindows(std::vector<WindowInfo>& out) {
    out.clear();
    EnumWindows(&EnumProc, reinterpret_cast<LPARAM>(&out));
}

RECT VisibleFrame(HWND hwnd) {
    RECT frame{};
    if (SUCCEEDED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &frame, sizeof(frame)))) {
        return frame;
    }
    GetWindowRect(hwnd, &frame);
    return frame;
}

std::wstring WindowTitle(HWND hwnd) {
    wchar_t buffer[512]{};
    DWORD_PTR result = 0;
    if (SendMessageTimeoutW(hwnd, WM_GETTEXT, 511, reinterpret_cast<LPARAM>(buffer),
                            SMTO_ABORTIFHUNG | SMTO_BLOCK, kTitleTimeoutMs, &result) == 0) {
        return {};
    }
    return buffer;
}

bool IsDarkAppTheme() {
    DWORD light = 1;
    DWORD size = sizeof(light);
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER,
                      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", 0,
                      KEY_READ, &key) == ERROR_SUCCESS) {
        RegQueryValueExW(key, L"AppsUseLightTheme", nullptr, nullptr, reinterpret_cast<LPBYTE>(&light), &size);
        RegCloseKey(key);
    }
    return light == 0;
}

float ScaleForWindow(HWND hwnd) {
    using GetDpiForWindowFn = UINT(WINAPI*)(HWND);
    static GetDpiForWindowFn get_dpi = reinterpret_cast<GetDpiForWindowFn>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"));
    UINT dpi = 96;
    if (get_dpi != nullptr && hwnd != nullptr) {
        dpi = get_dpi(hwnd);
    }
    if (dpi == 0) {
        dpi = 96;
    }
    return static_cast<float>(dpi) / 96.0f;
}

void EnableDpiAwareness() {
    using SetContextFn = BOOL(WINAPI*)(DPI_AWARENESS_CONTEXT);
    static SetContextFn set_context = reinterpret_cast<SetContextFn>(
        GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetProcessDpiAwarenessContext"));
    if (set_context != nullptr) {
        set_context(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    }
}
