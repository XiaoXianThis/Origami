#include "tab_bar.h"

#include <algorithm>
#include <cmath>

#include "window_enum.h"

namespace {

D2D1_COLOR_F BarBackground(bool dark) {
    return dark ? D2D1::ColorF(0.13f, 0.13f, 0.15f, 0.92f) : D2D1::ColorF(0.98f, 0.98f, 0.99f, 0.94f);
}

D2D1_COLOR_F BarBorder(bool dark) {
    return dark ? D2D1::ColorF(1.0f, 1.0f, 1.0f, 0.10f) : D2D1::ColorF(0.0f, 0.0f, 0.0f, 0.10f);
}

D2D1_COLOR_F ActiveTab(bool dark) {
    return dark ? D2D1::ColorF(1.0f, 1.0f, 1.0f, 0.16f) : D2D1::ColorF(0.0f, 0.42f, 0.75f, 0.14f);
}

D2D1_COLOR_F TabText(bool dark, bool active) {
    if (dark) {
        return D2D1::ColorF(1.0f, 1.0f, 1.0f, active ? 0.95f : 0.62f);
    }
    return D2D1::ColorF(0.12f, 0.12f, 0.14f, active ? 0.95f : 0.62f);
}

LONG ScaleToPx(float value, float scale) {
    return static_cast<LONG>(std::lround(value * scale));
}

}  // namespace

LONG TabBarMetrics::TabWidthPx() const {
    return ScaleToPx(tab_width, scale);
}

TabBarMetrics MetricsFor(HWND target) {
    TabBarMetrics metrics;
    metrics.scale = ScaleForWindow(target);
    if (metrics.scale <= 0.0f) {
        metrics.scale = 1.0f;
    }
    return metrics;
}

SIZE BarSize(const TabBarModel& model, const TabBarMetrics& metrics) {
    const LONG count = static_cast<LONG>(model.titles.size());
    const LONG tab_width = metrics.TabWidthPx();
    const LONG gap = ScaleToPx(metrics.gap, metrics.scale);
    const LONG inset = ScaleToPx(metrics.inset, metrics.scale);
    SIZE size{};
    size.cx = count > 0 ? count * tab_width + (count - 1) * gap + 2 * inset : 0;
    size.cy = ScaleToPx(metrics.bar_height, metrics.scale);
    return size;
}

std::vector<RECT> TabRects(const TabBarModel& model, const TabBarMetrics& metrics) {
    std::vector<RECT> rects;
    rects.reserve(model.titles.size());
    const LONG tab_width = metrics.TabWidthPx();
    const LONG tab_height = ScaleToPx(metrics.tab_height, metrics.scale);
    const LONG gap = ScaleToPx(metrics.gap, metrics.scale);
    const LONG bar_height = ScaleToPx(metrics.bar_height, metrics.scale);
    const LONG y = (bar_height - tab_height) / 2;
    LONG x = ScaleToPx(metrics.inset, metrics.scale);
    for (std::size_t i = 0; i < model.titles.size(); ++i) {
        rects.push_back(RECT{x, y, x + tab_width, y + tab_height});
        x += tab_width + gap;
    }
    return rects;
}

bool TabBarRenderer::Init() {
    if (FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &factory_))) {
        return false;
    }
    if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory),
                                   reinterpret_cast<IUnknown**>(&dwrite_)))) {
        return false;
    }
    const D2D1_RENDER_TARGET_PROPERTIES props = D2D1::RenderTargetProperties(
        D2D1_RENDER_TARGET_TYPE_DEFAULT,
        D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED));
    if (FAILED(factory_->CreateDCRenderTarget(&props, &target_))) {
        return false;
    }
    return SUCCEEDED(target_->CreateSolidColorBrush(D2D1::ColorF(0.0f, 0.0f, 0.0f, 1.0f), &brush_));
}

void TabBarRenderer::Shutdown() {
    if (ellipsis_ != nullptr) {
        ellipsis_->Release();
        ellipsis_ = nullptr;
    }
    if (text_ != nullptr) {
        text_->Release();
        text_ = nullptr;
    }
    if (brush_ != nullptr) {
        brush_->Release();
        brush_ = nullptr;
    }
    if (target_ != nullptr) {
        target_->Release();
        target_ = nullptr;
    }
    if (dwrite_ != nullptr) {
        dwrite_->Release();
        dwrite_ = nullptr;
    }
    if (factory_ != nullptr) {
        factory_->Release();
        factory_ = nullptr;
    }
}

bool TabBarRenderer::EnsureTextFormat(float font_size) {
    if (text_ != nullptr && std::fabs(text_size_ - font_size) < 0.01f) {
        return true;
    }
    if (ellipsis_ != nullptr) {
        ellipsis_->Release();
        ellipsis_ = nullptr;
    }
    if (text_ != nullptr) {
        text_->Release();
        text_ = nullptr;
    }
    if (FAILED(dwrite_->CreateTextFormat(L"Segoe UI", nullptr, DWRITE_FONT_WEIGHT_MEDIUM,
                                        DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL,
                                        font_size, L"zh-Hans", &text_))) {
        return false;
    }
    text_->SetTextAlignment(DWRITE_TEXT_ALIGNMENT_CENTER);
    text_->SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_CENTER);
    text_->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
    // Long titles end with an ellipsis instead of being cut mid-glyph or spilling
    // into the next tab.
    if (SUCCEEDED(dwrite_->CreateEllipsisTrimmingSign(text_, &ellipsis_)) && ellipsis_ != nullptr) {
        DWRITE_TRIMMING trimming{};
        trimming.granularity = DWRITE_TRIMMING_GRANULARITY_CHARACTER;
        text_->SetTrimming(&trimming, ellipsis_);
    }
    text_size_ = font_size;
    return true;
}

void TabBarRenderer::Paint(HDC dc, LONG width, LONG height, const TabBarModel& model,
                           const TabBarMetrics& metrics, bool dark) {
    if (target_ == nullptr || dwrite_ == nullptr || width <= 0 || height <= 0) {
        return;
    }
    if (!EnsureTextFormat(metrics.font_size * metrics.scale)) {
        return;
    }
    RECT area{0, 0, width, height};
    if (FAILED(target_->BindDC(dc, &area))) {
        return;
    }

    target_->BeginDraw();
    target_->Clear(D2D1::ColorF(0.0f, 0.0f, 0.0f, 0.0f));

    const float radius = metrics.bar_radius * metrics.scale;
    const D2D1_ROUNDED_RECT bar = D2D1::RoundedRect(
        D2D1::RectF(0.5f, 0.5f, static_cast<float>(width) - 0.5f, static_cast<float>(height) - 0.5f),
        radius, radius);
    brush_->SetColor(BarBackground(dark));
    target_->FillRoundedRectangle(bar, brush_);
    brush_->SetColor(BarBorder(dark));
    target_->DrawRoundedRectangle(bar, brush_, 1.0f);

    const std::vector<RECT> rects = TabRects(model, metrics);
    const float inset = 2.0f * metrics.scale;
    const float tab_radius = metrics.tab_radius * metrics.scale;
    const float text_pad = 8.0f * metrics.scale;

    for (std::size_t i = 0; i < rects.size() && i < model.titles.size(); ++i) {
        const bool active = static_cast<int>(i) == model.active;
        if (active) {
            const D2D1_ROUNDED_RECT tab = D2D1::RoundedRect(
                D2D1::RectF(static_cast<float>(rects[i].left) + inset,
                            static_cast<float>(rects[i].top) + inset,
                            static_cast<float>(rects[i].right) - inset,
                            static_cast<float>(rects[i].bottom) - inset),
                tab_radius, tab_radius);
            brush_->SetColor(ActiveTab(dark));
            target_->FillRoundedRectangle(tab, brush_);
        }
        brush_->SetColor(TabText(dark, active));
        const D2D1_RECT_F text_rect = D2D1::RectF(
            static_cast<float>(rects[i].left) + text_pad, static_cast<float>(rects[i].top),
            static_cast<float>(rects[i].right) - text_pad, static_cast<float>(rects[i].bottom));
        const std::wstring& title = model.titles[i];
        target_->DrawTextW(title.c_str(), static_cast<UINT32>(title.size()), text_, text_rect, brush_,
                           D2D1_DRAW_TEXT_OPTIONS_CLIP);
    }

    target_->EndDraw();
}

void TabBarRenderer::PaintHighlight(HDC dc, LONG width, LONG height, float scale, bool dark) {
    if (target_ == nullptr || width <= 0 || height <= 0) {
        return;
    }
    RECT area{0, 0, width, height};
    if (FAILED(target_->BindDC(dc, &area))) {
        return;
    }
    target_->BeginDraw();
    target_->Clear(D2D1::ColorF(0.0f, 0.0f, 0.0f, 0.0f));

    const float inset = 2.0f * scale;
    const float radius = 12.0f * scale;
    const D2D1_ROUNDED_RECT frame = D2D1::RoundedRect(
        D2D1::RectF(inset, inset, static_cast<float>(width) - inset, static_cast<float>(height) - inset),
        radius, radius);
    brush_->SetColor(dark ? D2D1::ColorF(0.35f, 0.62f, 1.0f, 0.14f) : D2D1::ColorF(0.0f, 0.42f, 0.75f, 0.10f));
    target_->FillRoundedRectangle(frame, brush_);
    brush_->SetColor(dark ? D2D1::ColorF(0.45f, 0.70f, 1.0f, 0.80f) : D2D1::ColorF(0.0f, 0.42f, 0.75f, 0.60f));
    target_->DrawRoundedRectangle(frame, brush_, 2.0f * scale);
    target_->EndDraw();
}
