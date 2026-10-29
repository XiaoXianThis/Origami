#pragma once

#include <windows.h>

#include <d2d1.h>
#include <dwrite.h>

#include <string>
#include <vector>

struct TabBarModel {
    std::vector<std::wstring> titles;
    int active = 0;
};

// Metrics in logical pixels; multiply by `scale` for device pixels.
struct TabBarMetrics {
    float scale = 1.0f;
    float bar_height = 26.0f;
    float tab_height = 22.0f;
    float gap = 4.0f;
    float tab_width = 120.0f;
    float font_size = 12.0f;
    float bar_radius = 8.0f;
    float tab_radius = 6.0f;
    float inset = 2.0f;

    LONG TabWidthPx() const;
};

TabBarMetrics MetricsFor(HWND target);

SIZE BarSize(const TabBarModel& model, const TabBarMetrics& metrics);
std::vector<RECT> TabRects(const TabBarModel& model, const TabBarMetrics& metrics);

// Paints a tab bar into a premultiplied 32-bit DIB that is handed to
// UpdateLayeredWindow. One instance is shared by every overlay.
class TabBarRenderer {
public:
    bool Init();
    void Shutdown();

    void Paint(HDC dc, LONG width, LONG height, const TabBarModel& model,
               const TabBarMetrics& metrics, bool dark);

    // Translucent frame shown over the window a dragged tab would merge into.
    void PaintHighlight(HDC dc, LONG width, LONG height, float scale, bool dark);

private:
    bool EnsureTextFormat(float font_size);

    ID2D1Factory* factory_ = nullptr;
    IDWriteFactory* dwrite_ = nullptr;
    ID2D1DCRenderTarget* target_ = nullptr;
    ID2D1SolidColorBrush* brush_ = nullptr;
    IDWriteTextFormat* text_ = nullptr;
    IDWriteInlineObject* ellipsis_ = nullptr;
    float text_size_ = 0.0f;
};
