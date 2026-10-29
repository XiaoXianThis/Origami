#include "overlay_window.h"

#include <windowsx.h>

#include <cmath>
#include <utility>

#include "app.h"
#include "log.h"

namespace {

constexpr wchar_t kOverlayClass[] = L"OrigamiWin.Overlay";
constexpr int kDragThreshold = 4;

}  // namespace

OverlayWindow::OverlayWindow(App* app, GroupId group, TabBarRenderer* renderer)
    : app_(app), group_(group), renderer_(renderer) {}

OverlayWindow::~OverlayWindow() {
    Destroy();
}

LRESULT CALLBACK OverlayWindow::WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    if (msg == WM_NCCREATE) {
        auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(create->lpCreateParams));
        return TRUE;
    }
    auto* self = reinterpret_cast<OverlayWindow*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (self == nullptr) {
        return DefWindowProcW(hwnd, msg, wparam, lparam);
    }
    return self->HandleMessage(msg, wparam, lparam);
}

bool OverlayWindow::Create() {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpfnWndProc = &OverlayWindow::WndProc;
    wc.lpszClassName = kOverlayClass;
    static const ATOM atom = RegisterClassExW(&wc);
    if (atom == 0) {
        return false;
    }
    hwnd_ = CreateWindowExW(WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
                            kOverlayClass, L"", WS_POPUP, 0, 0, 10, 10, nullptr, nullptr,
                            wc.hInstance, this);
    return hwnd_ != nullptr;
}

void OverlayWindow::Destroy() {
    ReleaseSurface();
    if (hwnd_ != nullptr) {
        DestroyWindow(hwnd_);
        hwnd_ = nullptr;
    }
}

void OverlayWindow::SetModel(TabBarModel model, const TabBarMetrics& metrics, bool dark) {
    const bool changed = model_.titles != model.titles || model_.active != model.active ||
                         std::fabs(metrics_.scale - metrics.scale) > 0.001f || dark_ != dark;
    model_ = std::move(model);
    metrics_ = metrics;
    dark_ = dark;
    tab_rects_ = TabRects(model_, metrics_);
    if (changed) {
        dirty_ = true;
        LogLine(L"model changed group=%llu active=%d", static_cast<unsigned long long>(group_),
                model_.active);
    }
}

void OverlayWindow::MoveTo(const RECT& rect, HWND target) {
    if (hwnd_ == nullptr) {
        return;
    }
    const int width = rect.right - rect.left;
    const int height = rect.bottom - rect.top;
    if (width <= 0 || height <= 0) {
        return;
    }
    if (width != surface_width_ || height != surface_height_) {
        if (!RebuildSurface(width, height)) {
            return;
        }
        dirty_ = true;
    }
    const bool dirty_before_paint = dirty_;
    if (dirty_) {
        renderer_->Paint(mem_dc_, width, height, model_, metrics_, dark_);
        dirty_ = false;
    }

    // Painting and presenting are separate costs: a bar that only changed z-order
    // must not be re-presented, but a bar whose content changed must be, even when
    // it did not move.
    if (dirty_before_paint || rect.left != applied_x_ || rect.top != applied_y_ ||
        width != applied_width_ || height != applied_height_) {
        HDC screen = GetDC(nullptr);
        POINT dst{rect.left, rect.top};
        POINT src{0, 0};
        SIZE size{width, height};
        BLENDFUNCTION blend{AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
        UpdateLayeredWindow(hwnd_, screen, &dst, &size, mem_dc_, &src, 0, &blend, ULW_ALPHA);
        ReleaseDC(nullptr, screen);
        applied_x_ = rect.left;
        applied_y_ = rect.top;
        applied_width_ = width;
        applied_height_ = height;
    }

    SetWindowPos(hwnd_, target, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
}

void OverlayWindow::Show() {
    if (hwnd_ != nullptr) {
        ShowWindow(hwnd_, SW_SHOWNOACTIVATE);
    }
}

void OverlayWindow::Hide() {
    if (hwnd_ != nullptr) {
        ShowWindow(hwnd_, SW_HIDE);
    }
}

int OverlayWindow::HitTabIndex(POINT client) const {
    for (std::size_t i = 0; i < tab_rects_.size(); ++i) {
        RECT rect = tab_rects_[i];
        if (PtInRect(&rect, client) != FALSE) {
            return static_cast<int>(i);
        }
    }
    return -1;
}

bool OverlayWindow::RebuildSurface(int width, int height) {
    ReleaseSurface();
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;

    mem_dc_ = CreateCompatibleDC(nullptr);
    if (mem_dc_ == nullptr) {
        return false;
    }
    bitmap_ = CreateDIBSection(mem_dc_, &info, DIB_RGB_COLORS, &bits_, nullptr, 0);
    if (bitmap_ == nullptr) {
        DeleteDC(mem_dc_);
        mem_dc_ = nullptr;
        return false;
    }
    old_bitmap_ = SelectObject(mem_dc_, bitmap_);
    surface_width_ = width;
    surface_height_ = height;
    return true;
}

void OverlayWindow::ReleaseSurface() {
    if (mem_dc_ != nullptr) {
        if (old_bitmap_ != nullptr) {
            SelectObject(mem_dc_, old_bitmap_);
            old_bitmap_ = nullptr;
        }
        DeleteDC(mem_dc_);
        mem_dc_ = nullptr;
    }
    if (bitmap_ != nullptr) {
        DeleteObject(bitmap_);
        bitmap_ = nullptr;
        bits_ = nullptr;
    }
    surface_width_ = 0;
    surface_height_ = 0;
    applied_x_ = INT_MIN;
    applied_y_ = INT_MIN;
    applied_width_ = 0;
    applied_height_ = 0;
}

LRESULT OverlayWindow::HandleMessage(UINT msg, WPARAM wparam, LPARAM lparam) {
    switch (msg) {
        case WM_MOUSEACTIVATE:
            return MA_NOACTIVATE;

        case WM_SETCURSOR: {
            POINT cursor{};
            GetCursorPos(&cursor);
            ScreenToClient(hwnd_, &cursor);
            if (dragging_) {
                SetCursor(LoadCursorW(nullptr, IDC_SIZEALL));
                return TRUE;
            }
            if (HitTabIndex(cursor) >= 0) {
                SetCursor(LoadCursorW(nullptr, IDC_HAND));
                return TRUE;
            }
            break;
        }

        case WM_LBUTTONDOWN: {
            const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
            press_tab_ = HitTabIndex(point);
            LogLine(L"down group=%llu pt=(%d,%d) tab=%d", static_cast<unsigned long long>(group_),
                    point.x, point.y, press_tab_);
            if (press_tab_ >= 0) {
                press_point_ = point;
                dragging_ = false;
                SetCapture(hwnd_);
            }
            return 0;
        }

        case WM_MOUSEMOVE: {
            if (press_tab_ >= 0 && GetCapture() == hwnd_) {
                const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
                if (!dragging_ &&
                    std::abs(point.x - press_point_.x) + std::abs(point.y - press_point_.y) > kDragThreshold) {
                    dragging_ = true;
                    LogLine(L"drag start group=%llu tab=%d", static_cast<unsigned long long>(group_),
                            press_tab_);
                    if (app_ != nullptr) {
                        app_->OnTabDragBegan(group_, press_tab_);
                    }
                }
                if (dragging_ && app_ != nullptr) {
                    POINT screen = point;
                    ClientToScreen(hwnd_, &screen);
                    app_->OnTabDragMoved(group_, press_tab_, screen);
                }
            }
            return 0;
        }

        case WM_LBUTTONUP: {
            if (press_tab_ < 0) {
                LogLine(L"up ignored: no pressed tab");
                return 0;
            }
            POINT screen{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
            ClientToScreen(hwnd_, &screen);
            const int tab = press_tab_;
            const bool dragged = dragging_;
            press_tab_ = -1;
            dragging_ = false;
            if (GetCapture() == hwnd_) {
                ReleaseCapture();
            }
            LogLine(L"up group=%llu tab=%d dragged=%d screen=(%ld,%ld)",
                    static_cast<unsigned long long>(group_), tab, dragged ? 1 : 0, screen.x, screen.y);
            if (app_ != nullptr) {
                if (dragged) {
                    app_->OnTabDropped(group_, tab, screen);
                } else {
                    app_->OnTabClicked(group_, tab);
                }
            }
            return 0;
        }

        case WM_CAPTURECHANGED:
            LogLine(L"capture changed group=%llu pressed=%d", static_cast<unsigned long long>(group_),
                    press_tab_);
            press_tab_ = -1;
            dragging_ = false;
            if (app_ != nullptr) {
                app_->OnTabDragCancelled();
            }
            return 0;

        case WM_DESTROY:
            ReleaseSurface();
            SetWindowLongPtrW(hwnd_, GWLP_USERDATA, 0);
            return 0;

        default:
            return DefWindowProcW(hwnd_, msg, wparam, lparam);
    }
    return DefWindowProcW(hwnd_, msg, wparam, lparam);
}
