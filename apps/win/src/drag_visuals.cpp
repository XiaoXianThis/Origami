#include "drag_visuals.h"

#include "log.h"

namespace {

constexpr wchar_t kDragVisualClass[] = L"OrigamiWin.DragVisual";

}  // namespace

bool DragVisuals::Init(TabBarRenderer* renderer) {
    renderer_ = renderer;
    return renderer_ != nullptr;
}

bool DragVisuals::EnsureWindow(HWND* hwnd) {
    if (*hwnd != nullptr) {
        return true;
    }
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpfnWndProc = &DragVisuals::WndProc;
    wc.lpszClassName = kDragVisualClass;
    static const ATOM atom = RegisterClassExW(&wc);
    if (atom == 0) {
        return false;
    }
    // WS_EX_TRANSPARENT keeps every drag visual out of hit testing, so the ghost
    // can never steal the mouse from the drag it illustrates.
    *hwnd = CreateWindowExW(WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE |
                                WS_EX_TRANSPARENT | WS_EX_TOPMOST,
                            kDragVisualClass, L"", WS_POPUP, 0, 0, 10, 10, nullptr, nullptr,
                            wc.hInstance, nullptr);
    return *hwnd != nullptr;
}

LRESULT CALLBACK DragVisuals::WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    if (msg == WM_NCHITTEST) {
        return HTTRANSPARENT;
    }
    return DefWindowProcW(hwnd, msg, wparam, lparam);
}

bool DragVisuals::EnsureSurface(Surface* surface, int width, int height) {
    if (surface->dc != nullptr && surface->width == width && surface->height == height) {
        return true;
    }
    ReleaseSurface(surface);
    if (width <= 0 || height <= 0) {
        return false;
    }
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;

    surface->dc = CreateCompatibleDC(nullptr);
    if (surface->dc == nullptr) {
        return false;
    }
    surface->bitmap = CreateDIBSection(surface->dc, &info, DIB_RGB_COLORS, &surface->bits, nullptr, 0);
    if (surface->bitmap == nullptr) {
        DeleteDC(surface->dc);
        surface->dc = nullptr;
        return false;
    }
    surface->old_bitmap = SelectObject(surface->dc, surface->bitmap);
    surface->width = width;
    surface->height = height;
    return true;
}

void DragVisuals::ReleaseSurface(Surface* surface) {
    if (surface->dc != nullptr) {
        if (surface->old_bitmap != nullptr) {
            SelectObject(surface->dc, surface->old_bitmap);
            surface->old_bitmap = nullptr;
        }
        DeleteDC(surface->dc);
        surface->dc = nullptr;
    }
    if (surface->bitmap != nullptr) {
        DeleteObject(surface->bitmap);
        surface->bitmap = nullptr;
        surface->bits = nullptr;
    }
    surface->width = 0;
    surface->height = 0;
}

bool DragVisuals::Present(HWND hwnd, Surface* surface, const RECT& rect) {
    if (hwnd == nullptr || surface->dc == nullptr) {
        return false;
    }
    HDC screen = GetDC(nullptr);
    POINT dst{rect.left, rect.top};
    POINT src{0, 0};
    SIZE size{rect.right - rect.left, rect.bottom - rect.top};
    BLENDFUNCTION blend{AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
    const bool ok =
        UpdateLayeredWindow(hwnd, screen, &dst, &size, surface->dc, &src, 0, &blend, ULW_ALPHA) != FALSE;
    ReleaseDC(nullptr, screen);
    return ok;
}

void DragVisuals::Begin(const std::wstring& title, const TabBarMetrics& metrics, bool dark,
                        POINT cursor) {
    if (!EnsureWindow(&ghost_)) {
        return;
    }
    TabBarModel model;
    model.titles.push_back(title);
    model.active = 0;
    const SIZE size = BarSize(model, metrics);
    if (!EnsureSurface(&ghost_surface_, size.cx, size.cy)) {
        return;
    }
    renderer_->Paint(ghost_surface_.dc, size.cx, size.cy, model, metrics, dark);
    MoveGhost(cursor);
    ShowWindow(ghost_, SW_SHOWNOACTIVATE);
    LogLine(L"ghost begin size=%ldx%ld", size.cx, size.cy);
}

void DragVisuals::MoveGhost(POINT cursor) {
    if (ghost_ == nullptr || ghost_surface_.dc == nullptr) {
        return;
    }
    RECT rect{cursor.x + ghost_offset_x_, cursor.y + ghost_offset_y_,
              cursor.x + ghost_offset_x_ + ghost_surface_.width,
              cursor.y + ghost_offset_y_ + ghost_surface_.height};
    Present(ghost_, &ghost_surface_, rect);
}

void DragVisuals::ShowHighlight(const RECT& frame, float scale, bool dark) {
    const int width = frame.right - frame.left;
    const int height = frame.bottom - frame.top;
    if (!EnsureWindow(&highlight_) || !EnsureSurface(&highlight_surface_, width, height)) {
        return;
    }
    renderer_->PaintHighlight(highlight_surface_.dc, width, height, scale, dark);
    Present(highlight_, &highlight_surface_, frame);
    if (!highlight_visible_) {
        ShowWindow(highlight_, SW_SHOWNOACTIVATE);
        highlight_visible_ = true;
        LogLine(L"highlight show rect=(%ld,%ld) %dx%d", frame.left, frame.top, width, height);
    }
}

void DragVisuals::HideHighlight() {
    if (highlight_ != nullptr && highlight_visible_) {
        ShowWindow(highlight_, SW_HIDE);
        highlight_visible_ = false;
    }
}

void DragVisuals::End() {
    HideHighlight();
    if (ghost_ != nullptr) {
        ShowWindow(ghost_, SW_HIDE);
    }
    ReleaseSurface(&ghost_surface_);
    ReleaseSurface(&highlight_surface_);
    LogLine(L"drag visuals end");
}
