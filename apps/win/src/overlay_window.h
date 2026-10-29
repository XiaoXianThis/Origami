#pragma once

#include <windows.h>

#include <vector>

#include "group_store.h"
#include "tab_bar.h"

class App;

// One layered, non-activating tab bar. Alpha-zero pixels are click-through,
// and the window is kept directly above its target window in the z-order.
class OverlayWindow {
public:
    OverlayWindow(App* app, GroupId group, TabBarRenderer* renderer);
    ~OverlayWindow();

    OverlayWindow(const OverlayWindow&) = delete;
    OverlayWindow& operator=(const OverlayWindow&) = delete;

    static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);

    bool Create();
    void SetModel(TabBarModel model, const TabBarMetrics& metrics, bool dark);
    void MoveTo(const RECT& rect, HWND target);
    void Show();
    void Hide();
    void Destroy();

    HWND hwnd() const { return hwnd_; }
    GroupId group() const { return group_; }
    const TabBarMetrics& metrics() const { return metrics_; }
    int HitTabIndex(POINT client) const;

private:
    LRESULT HandleMessage(UINT msg, WPARAM wparam, LPARAM lparam);
    bool RebuildSurface(int width, int height);
    void ReleaseSurface();

    App* app_ = nullptr;
    GroupId group_ = 0;
    TabBarRenderer* renderer_ = nullptr;
    HWND hwnd_ = nullptr;

    TabBarModel model_;
    TabBarMetrics metrics_{};
    std::vector<RECT> tab_rects_;
    bool dark_ = false;
    bool dirty_ = true;

    HDC mem_dc_ = nullptr;
    HBITMAP bitmap_ = nullptr;
    HGDIOBJ old_bitmap_ = nullptr;
    void* bits_ = nullptr;
    int surface_width_ = 0;
    int surface_height_ = 0;

    int applied_x_ = INT_MIN;
    int applied_y_ = INT_MIN;
    int applied_width_ = 0;
    int applied_height_ = 0;

    int press_tab_ = -1;
    bool dragging_ = false;
    POINT press_point_{};
};
