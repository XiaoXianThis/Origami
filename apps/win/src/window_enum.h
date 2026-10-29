#pragma once

#include <windows.h>

#include <string>
#include <vector>

struct WindowInfo {
    HWND hwnd = nullptr;
    DWORD pid = 0;
    bool minimized = false;
    RECT frame{};
};

// Enumerates top-level app windows that are visible, not cloaked, owned by another
// process, and large enough to carry a tab bar. Titles are not read here: they cost a
// cross-process message, so the caller resolves them through a cache.
void EnumerateWindows(std::vector<WindowInfo>& out);

// Visible frame in physical pixels, excluding the invisible resize border.
RECT VisibleFrame(HWND hwnd);

// Title with a short cross-process budget: a hung app must not stall the refresh.
std::wstring WindowTitle(HWND hwnd);

bool IsDarkAppTheme();

// DPI scale of the window (1.0 at 96 DPI), resolved at runtime.
float ScaleForWindow(HWND hwnd);

void EnableDpiAwareness();
