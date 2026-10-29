#pragma once

#include <windows.h>

#include <string>

#include "tab_bar.h"

// Two click-through overlay windows used while a tab is dragged: a ghost that
// follows the cursor and a frame over the window the tab would merge into.
class DragVisuals {
public:
    bool Init(TabBarRenderer* renderer);

    void Begin(const std::wstring& title, const TabBarMetrics& metrics, bool dark, POINT cursor);
    void MoveGhost(POINT cursor);
    void ShowHighlight(const RECT& frame, float scale, bool dark);
    void HideHighlight();
    void End();

private:
    struct Surface {
        HDC dc = nullptr;
        HBITMAP bitmap = nullptr;
        HGDIOBJ old_bitmap = nullptr;
        void* bits = nullptr;
        int width = 0;
        int height = 0;
    };

    static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);

    bool EnsureWindow(HWND* hwnd);
    bool EnsureSurface(Surface* surface, int width, int height);
    void ReleaseSurface(Surface* surface);
    bool Present(HWND hwnd, Surface* surface, const RECT& rect);

    TabBarRenderer* renderer_ = nullptr;
    HWND ghost_ = nullptr;
    HWND highlight_ = nullptr;
    Surface ghost_surface_;
    Surface highlight_surface_;
    int ghost_offset_x_ = 16;
    int ghost_offset_y_ = 14;
    bool highlight_visible_ = false;
};
