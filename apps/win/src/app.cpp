#include "app.h"

#include <shellapi.h>

#include <algorithm>
#include <cmath>
#include <utility>

#include "overlay_window.h"
#include "log.h"
#include "window_enum.h"

namespace {

constexpr wchar_t kMessageClass[] = L"OrigamiWin.Message";
constexpr wchar_t kSingletonName[] = L"Local\\Origami.Win.Singleton";
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kShowMessage = WM_APP + 2;
constexpr UINT_PTR kRefreshTimer = 1;
constexpr UINT_PTR kIdleTimer = 2;
constexpr UINT_PTR kFocusTimer = 3;
constexpr UINT kMenuToggle = 100;
constexpr UINT kMenuRestore = 101;
constexpr UINT kMenuHideOffscreen = 110;
constexpr UINT kMenuHideMinimize = 111;
constexpr UINT kMenuMatchFrame = 112;
constexpr UINT kMenuExit = 120;
constexpr int kRefreshCoalesceMs = 30;
constexpr int kIdleRefreshMs = 2000;
constexpr int kBarGap = 4;

RECT BarRectFor(const RECT& frame, SIZE size, float scale, HWND target) {
    const LONG gap = static_cast<LONG>(std::lround(kBarGap * scale));
    RECT bar{};
    bar.left = frame.left + ((frame.right - frame.left) - size.cx) / 2;
    bar.top = frame.top - size.cy - gap;
    bar.right = bar.left + size.cx;
    bar.bottom = bar.top + size.cy;

    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    if (GetMonitorInfoW(MonitorFromWindow(target, MONITOR_DEFAULTTONEAREST), &monitor) != FALSE) {
        if (bar.top < monitor.rcWork.top) {
            bar.top = frame.top + gap;
            bar.bottom = bar.top + size.cy;
        }
        if (bar.left < monitor.rcWork.left) {
            const LONG delta = monitor.rcWork.left - bar.left;
            bar.left += delta;
            bar.right += delta;
        }
        if (bar.right > monitor.rcWork.right) {
            const LONG delta = bar.right - monitor.rcWork.right;
            bar.left -= delta;
            bar.right -= delta;
        }
    }
    return bar;
}

// A tab click happens while another app owns the foreground, so the activation
// needs the AttachThreadInput workaround around SetForegroundWindow.
void ForceForeground(HWND hwnd) {
    if (hwnd == nullptr) {
        return;
    }
    const HWND foreground = GetForegroundWindow();
    const DWORD foreground_thread =
        foreground != nullptr ? GetWindowThreadProcessId(foreground, nullptr) : 0;
    const DWORD self_thread = GetCurrentThreadId();
    bool attached = false;
    if (foreground_thread != 0 && foreground_thread != self_thread) {
        attached = AttachThreadInput(self_thread, foreground_thread, TRUE) != FALSE;
    }
    SetForegroundWindow(hwnd);
    if (attached) {
        AttachThreadInput(self_thread, foreground_thread, FALSE);
    }
}

// Give `target` the same visible bounds as `source`. Each app has its own
// invisible resize border, so the target's window rect is adjusted by its own
// frame insets; copying the window rect directly would misalign the two windows.
void MatchWindowFrame(HWND source, HWND target) {
    if (source == nullptr || target == nullptr || source == target || !IsWindow(source) ||
        !IsWindow(target) || IsIconic(source)) {
        return;
    }
    if (IsZoomed(source) != FALSE) {
        ShowWindow(target, SW_MAXIMIZE);
        return;
    }
    if (IsZoomed(target) != FALSE) {
        ShowWindow(target, SW_RESTORE);
    }

    const RECT source_frame = VisibleFrame(source);
    RECT target_window{};
    if (GetWindowRect(target, &target_window) == FALSE) {
        return;
    }
    const RECT target_frame = VisibleFrame(target);
    const int left_inset = target_frame.left - target_window.left;
    const int top_inset = target_frame.top - target_window.top;
    const int right_inset = target_window.right - target_frame.right;
    const int bottom_inset = target_window.bottom - target_frame.bottom;

    const int width = (source_frame.right - source_frame.left) + left_inset + right_inset;
    const int height = (source_frame.bottom - source_frame.top) + top_inset + bottom_inset;
    if (width <= 0 || height <= 0) {
        return;
    }
    SetWindowPos(target, nullptr, source_frame.left - left_inset, source_frame.top - top_inset,
                 width, height, SWP_NOZORDER | SWP_NOACTIVATE);
    LogLine(L"frame match target=%p -> (%ld,%ld) %dx%d", static_cast<void*>(target),
            source_frame.left - left_inset, source_frame.top - top_inset, width, height);
}

}  // namespace

App& App::Instance() {
    static App instance;
    return instance;
}

int App::Run(HINSTANCE instance, int) {
    instance_ = instance;
    EnableDpiAwareness();
    const HRESULT com_result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    HANDLE mutex = CreateMutexW(nullptr, TRUE, kSingletonName);
    if (mutex != nullptr && GetLastError() == ERROR_ALREADY_EXISTS) {
        if (HWND existing = FindWindowW(kMessageClass, nullptr)) {
            PostMessageW(existing, kShowMessage, 0, 0);
        }
        return 0;
    }

    if (!renderer_.Init()) {
        MessageBoxW(nullptr, L"Direct2D 初始化失败，无法绘制标签栏。", L"Origami",
                    MB_ICONERROR | MB_OK);
        return 1;
    }

    CreateMessageWindow();
    if (msg_hwnd_ == nullptr) {
        return 1;
    }
    LogLine(L"startup hide_mode=%d enabled=%d restore_on_exit=%d match_frame=%d",
            static_cast<int>(Settings::Get().hide_mode), Settings::Get().enabled ? 1 : 0,
            Settings::Get().restore_on_exit ? 1 : 0, Settings::Get().match_window_frame ? 1 : 0);
    AddTrayIcon();
    InstallEventHooks();
    drag_visuals_.Init(&renderer_);
    SetTimer(msg_hwnd_, kIdleTimer, kIdleRefreshMs, nullptr);
    RefreshNow();

    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    shutting_down_ = true;
    if (Settings::Get().restore_on_exit) {
        RestoreAllHidden();
    }
    RemoveEventHooks();
    RemoveTrayIcon();
    if (msg_hwnd_ != nullptr) {
        DestroyWindow(msg_hwnd_);
        msg_hwnd_ = nullptr;
    }
    overlays_.clear();
    renderer_.Shutdown();
    if (SUCCEEDED(com_result)) {
        CoUninitialize();
    }
    return static_cast<int>(msg.wParam);
}

void App::CreateMessageWindow() {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.hInstance = instance_;
    wc.lpfnWndProc = &App::MessageProc;
    wc.lpszClassName = kMessageClass;
    if (RegisterClassExW(&wc) == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
        return;
    }
    msg_hwnd_ = CreateWindowExW(0, kMessageClass, L"Origami", 0, 0, 0, 0, 0, nullptr, nullptr,
                                instance_, nullptr);
}

void App::AddTrayIcon() {
    tray_.cbSize = sizeof(tray_);
    tray_.hWnd = msg_hwnd_;
    tray_.uID = 1;
    tray_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    tray_.uCallbackMessage = kTrayMessage;
    tray_.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    wcscpy_s(tray_.szTip, L"Origami");
    Shell_NotifyIconW(NIM_ADD, &tray_);
}

void App::RemoveTrayIcon() {
    Shell_NotifyIconW(NIM_DELETE, &tray_);
}

void App::InstallEventHooks() {
    const DWORD events[] = {
        EVENT_OBJECT_LOCATIONCHANGE, EVENT_OBJECT_NAMECHANGE, EVENT_OBJECT_CREATE,
        EVENT_OBJECT_DESTROY,        EVENT_OBJECT_SHOW,       EVENT_OBJECT_HIDE,
        EVENT_OBJECT_CLOAKED,        EVENT_OBJECT_UNCLOAKED,  EVENT_SYSTEM_FOREGROUND,
    };
    for (DWORD event : events) {
        HWINEVENTHOOK hook = SetWinEventHook(event, event, nullptr, &App::WinEventProc, 0, 0,
                                            WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
        if (hook != nullptr) {
            hooks_.push_back(hook);
        }
    }
}

void App::RemoveEventHooks() {
    for (HWINEVENTHOOK hook : hooks_) {
        UnhookWinEvent(hook);
    }
    hooks_.clear();
}

LRESULT CALLBACK App::MessageProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    return App::Instance().HandleMessage(hwnd, msg, wparam, lparam);
}

LRESULT App::HandleMessage(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
    switch (msg) {
        case kTrayMessage:
            switch (LOWORD(lparam)) {
                case WM_RBUTTONUP:
                case WM_CONTEXTMENU:
                    ShowTrayMenu();
                    break;
                case WM_LBUTTONDBLCLK:
                    RefreshNow();
                    break;
                default:
                    break;
            }
            return 0;

        case kShowMessage:
            RefreshNow();
            return 0;

        case WM_TIMER:
            if (wparam == kRefreshTimer) {
                KillTimer(hwnd, kRefreshTimer);
                refresh_timer_ = 0;
                RefreshNow();
            } else if (wparam == kIdleTimer) {
                RefreshNow();
            } else if (wparam == kFocusTimer) {
                KillTimer(hwnd, kFocusTimer);
                if (pending_foreground_ != nullptr) {
                    if (!IsWindow(pending_foreground_)) {
                        pending_foreground_ = nullptr;
                        focus_retries_ = 0;
                        return 0;
                    }
                    if (GetForegroundWindow() != pending_foreground_) {
                        ForceForeground(pending_foreground_);
                    }
                    if (focus_retries_ < 3 && GetForegroundWindow() != pending_foreground_) {
                        ++focus_retries_;
                        SetTimer(hwnd, kFocusTimer, 120, nullptr);
                    } else {
                        pending_foreground_ = nullptr;
                        focus_retries_ = 0;
                    }
                }
            }
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
            return DefWindowProcW(hwnd, msg, wparam, lparam);
    }
}

void App::ShowTrayMenu() {
    Settings& settings = Settings::Get();
    HMENU menu = CreatePopupMenu();
    HMENU hide_menu = CreatePopupMenu();
    if (menu == nullptr || hide_menu == nullptr) {
        if (hide_menu != nullptr) DestroyMenu(hide_menu);
        if (menu != nullptr) DestroyMenu(menu);
        return;
    }

    AppendMenuW(menu, MF_STRING | (settings.enabled ? MF_CHECKED : 0), kMenuToggle, L"启用 Origami");
    AppendMenuW(menu, MF_STRING, kMenuRestore, L"复原全部窗口");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(hide_menu,
                MF_STRING | (settings.hide_mode == HideMode::kMoveOffscreen ? MF_CHECKED : 0),
                kMenuHideOffscreen, L"移动到屏外");
    AppendMenuW(hide_menu,
                MF_STRING | (settings.hide_mode == HideMode::kMinimize ? MF_CHECKED : 0),
                kMenuHideMinimize, L"最小化");
    AppendMenuW(menu, MF_POPUP, reinterpret_cast<UINT_PTR>(hide_menu), L"隐藏方式");
    AppendMenuW(menu, MF_STRING | (settings.match_window_frame ? MF_CHECKED : 0), kMenuMatchFrame,
                L"切换时匹配窗口大小");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, kMenuExit, L"退出");

    POINT cursor{};
    GetCursorPos(&cursor);
    SetForegroundWindow(msg_hwnd_);
    const UINT command = TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY,
                                        cursor.x, cursor.y, 0, msg_hwnd_, nullptr);
    DestroyMenu(menu);
    PostMessageW(msg_hwnd_, WM_NULL, 0, 0);

    switch (command) {
        case kMenuToggle:
            settings.enabled = !settings.enabled;
            settings.Save();
            if (!settings.enabled) {
                RestoreAllHidden();
            }
            RefreshNow();
            break;
        case kMenuRestore:
            RestoreAll();
            break;
        case kMenuHideOffscreen:
        case kMenuHideMinimize: {
            const HideMode mode =
                command == kMenuHideMinimize ? HideMode::kMinimize : HideMode::kMoveOffscreen;
            if (mode != settings.hide_mode) {
                RestoreAllHidden();
                settings.hide_mode = mode;
                settings.Save();
                RefreshNow();
            }
            break;
        }
        case kMenuMatchFrame:
            settings.match_window_frame = !settings.match_window_frame;
            settings.Save();
            break;
        case kMenuExit:
            PostMessageW(msg_hwnd_, WM_CLOSE, 0, 0);
            break;
        default:
            break;
    }
}

void App::ScheduleRefresh() {
    if (msg_hwnd_ == nullptr || shutting_down_ || refresh_timer_ != 0) {
        return;
    }
    refresh_timer_ = SetTimer(msg_hwnd_, kRefreshTimer, kRefreshCoalesceMs, nullptr);
}

void App::MarkTitleDirty(HWND hwnd) {
    if (hwnd != nullptr) {
        dirty_titles_.insert(hwnd);
    }
}

std::wstring App::TitleFor(HWND hwnd) {
    auto cached = title_cache_.find(hwnd);
    if (cached != title_cache_.end() && dirty_titles_.count(hwnd) == 0) {
        return cached->second;
    }
    std::wstring title = WindowTitle(hwnd);
    if (title.empty()) {
        title = L"窗口";
    }
    title_cache_[hwnd] = title;
    dirty_titles_.erase(hwnd);
    return title;
}

OverlayWindow* App::OverlayFor(GroupId group, bool create) {
    auto found = overlays_.find(group);
    if (found != overlays_.end()) {
        return found->second.get();
    }
    if (!create) {
        return nullptr;
    }
    auto overlay = std::make_unique<OverlayWindow>(this, group, &renderer_);
    if (!overlay->Create()) {
        return nullptr;
    }
    OverlayWindow* raw = overlay.get();
    overlays_.emplace(group, std::move(overlay));
    return raw;
}

void App::RefreshNow() {
    if (shutting_down_) {
        return;
    }
    std::vector<WindowInfo> infos;
    EnumerateWindows(infos);

    std::vector<HWND> alive;
    alive.reserve(infos.size());
    for (const WindowInfo& info : infos) {
        alive.push_back(info.hwnd);
    }
    for (HWND previous : known_windows_) {
        if (std::find(alive.begin(), alive.end(), previous) == alive.end()) {
            const RECT frame = VisibleFrame(previous);
            LogLine(L"lost hwnd=%p visible=%d iconic=%d frame=(%ld,%ld,%ld,%ld)",
                    static_cast<void*>(previous), IsWindowVisible(previous) ? 1 : 0,
                    IsIconic(previous) ? 1 : 0, frame.left, frame.top, frame.right, frame.bottom);
        }
    }
    known_windows_.clear();
    known_windows_.insert(alive.begin(), alive.end());
    groups_.Sync(alive);
    {
        std::size_t total = 0;
        for (const Group& group : groups_.All()) {
            total += group.windows.size();
        }
        if (groups_.All().size() != last_group_count_ || total != last_window_count_) {
            last_group_count_ = groups_.All().size();
            last_window_count_ = total;
            LogLine(L"refresh: groups=%zu managed_windows=%zu enumerated=%zu",
                    last_group_count_, last_window_count_, infos.size());
            for (const Group& group : groups_.All()) {
                LogLine(L"  group=%llu windows=%zu active=%zu", static_cast<unsigned long long>(group.id),
                        group.windows.size(), group.active);
            }
        }
    }

    for (auto it = hidden_.begin(); it != hidden_.end();) {
        if (groups_.FindByWindow(*it) == nullptr) {
            saved_rects_.erase(*it);
            it = hidden_.erase(it);
        } else {
            ++it;
        }
    }
    for (auto it = title_cache_.begin(); it != title_cache_.end();) {
        if (groups_.FindByWindow(it->first) == nullptr && dirty_titles_.count(it->first) == 0) {
            it = title_cache_.erase(it);
        } else {
            ++it;
        }
    }

    dark_ = IsDarkAppTheme();

    Settings& settings = Settings::Get();
    if (!settings.enabled) {
        for (auto& entry : overlays_) {
            entry.second->Hide();
        }
        return;
    }

    std::set<GroupId> live;
    for (Group& group : groups_.All()) {
        live.insert(group.id);
    }
    for (auto it = overlays_.begin(); it != overlays_.end();) {
        if (live.count(it->first) == 0) {
            it = overlays_.erase(it);
        } else {
            ++it;
        }
    }

    for (Group& group : groups_.All()) {
        OverlayWindow* overlay = OverlayFor(group.id, true);
        if (overlay == nullptr) {
            continue;
        }
        const HWND active = group.ActiveWindow();
        if (active == nullptr) {
            overlay->Hide();
            continue;
        }
        // The active window must never stay hidden: it can become active when a
        // neighbour closes while the group was collapsed.
        if (hidden_.count(active) != 0) {
            RestoreHidden(active);
        }
        const WindowInfo* info = nullptr;
        for (const WindowInfo& candidate : infos) {
            if (candidate.hwnd == active) {
                info = &candidate;
                break;
            }
        }
        // A minimized window has no meaningful frame to anchor to; the bar comes
        // back on the event that restores it.
        if (info == nullptr || info->minimized || IsIconic(active) != FALSE) {
            overlay->Hide();
            continue;
        }

        TabBarModel model;
        model.titles.reserve(group.windows.size());
        for (HWND hwnd : group.windows) {
            model.titles.push_back(TitleFor(hwnd));
        }
        model.active = static_cast<int>(std::min(group.active, model.titles.size() - 1));

        const TabBarMetrics metrics = MetricsFor(active);
        const SIZE size = BarSize(model, metrics);
        const RECT bar = BarRectFor(info->frame, size, metrics.scale, active);
        overlay->SetModel(std::move(model), metrics, dark_);
        overlay->MoveTo(bar, active);
        overlay->Show();
    }
}

void App::OnTabClicked(GroupId group, int index) {
    if (index < 0) {
        return;
    }
    SwitchTo(group, static_cast<std::size_t>(index));
}

App::DropResolution App::ResolveDrop(GroupId source, POINT screen) {
    DropResolution result;
    HWND hit = WindowFromPoint(screen);
    if (hit == nullptr) {
        return result;
    }
    HWND root = GetAncestor(hit, GA_ROOT);
    for (auto& entry : overlays_) {
        if (entry.second->hwnd() != hit && entry.second->hwnd() != root) {
            continue;
        }
        // The source's own bar is a cancel, not a detach.
        result.on_window = true;
        if (entry.first == source) {
            return result;
        }
        result.group = entry.first;
        result.on_bar = true;
        if (Group* group = groups_.Find(entry.first)) {
            if (HWND active = group->ActiveWindow()) {
                result.frame = VisibleFrame(active);
                result.scale = ScaleForWindow(active);
            }
        }
        return result;
    }
    // Any window of another group is a merge target: dropping a tab on the window
    // body is the natural gesture, not only on its bar.
    const HWND top_level = root != nullptr ? root : hit;
    if (Group* group = groups_.FindByWindow(top_level)) {
        result.group = group->id;
        result.on_window = true;
        if (HWND active = group->ActiveWindow()) {
            result.frame = VisibleFrame(active);
            result.scale = ScaleForWindow(active);
        }
    }
    return result;
}

void App::OnTabDragBegan(GroupId group, int index) {
    Group* target = groups_.Find(group);
    if (target == nullptr || index < 0 ||
        static_cast<std::size_t>(index) >= target->windows.size()) {
        return;
    }
    drag_group_ = group;
    drag_index_ = index;
    POINT cursor{};
    GetCursorPos(&cursor);
    const HWND window = target->windows[static_cast<std::size_t>(index)];
    drag_visuals_.Begin(TitleFor(window), MetricsFor(window), dark_, cursor);
    LogLine(L"drag began group=%llu index=%d window=%p", static_cast<unsigned long long>(group),
            index, static_cast<void*>(window));
}

void App::OnTabDragMoved(GroupId group, int index, POINT screen) {
    if (group != drag_group_ || index != drag_index_) {
        return;
    }
    drag_visuals_.MoveGhost(screen);
    const DropResolution resolution = ResolveDrop(group, screen);
    if (resolution.group != 0 && resolution.group != group &&
        resolution.frame.right > resolution.frame.left) {
        drag_visuals_.ShowHighlight(resolution.frame, resolution.scale, dark_);
    } else {
        drag_visuals_.HideHighlight();
    }
}

void App::OnTabDragCancelled() {
    drag_visuals_.End();
    drag_group_ = 0;
    drag_index_ = -1;
}

void App::OnTabDropped(GroupId group, int index, POINT screen) {
    const DropResolution resolution = ResolveDrop(group, screen);
    drag_visuals_.End();
    drag_group_ = 0;
    drag_index_ = -1;

    Group* source = groups_.Find(group);
    if (source == nullptr || index < 0 ||
        static_cast<std::size_t>(index) >= source->windows.size()) {
        LogLine(L"drop: bad source group=%llu index=%d", static_cast<unsigned long long>(group), index);
        return;
    }
    const HWND window = source->windows[static_cast<std::size_t>(index)];
    LogLine(L"drop: window=%p target_group=%llu on_bar=%d source_group=%llu", static_cast<void*>(window),
            static_cast<unsigned long long>(resolution.group), resolution.on_bar ? 1 : 0,
            static_cast<unsigned long long>(group));

    if (resolution.group != 0 && resolution.group != group) {
        // The slot must be read before the merge, which makes the incoming window
        // the target group's active one.
        HWND slot_source = nullptr;
        if (Group* target = groups_.Find(resolution.group)) {
            slot_source = target->ActiveWindow();
        }
        if (groups_.Merge(window, resolution.group)) {
            LogLine(L"drop: merged into %llu", static_cast<unsigned long long>(resolution.group));
            if (Group* merged = groups_.Find(resolution.group)) {
                SwitchTo(resolution.group, merged->active, slot_source);
            }
        }
        ScheduleRefresh();
        return;
    }

    // Dropped over empty desktop while the group holds more than one window:
    // pull the tab out into a group of its own. Dropping back on the source's own
    // bar or window is a cancel.
    if (!resolution.on_window && resolution.group == 0 && source->windows.size() > 1) {
        groups_.Detach(window);
        LogLine(L"drop: detached %p", static_cast<void*>(window));
        if (Group* own = groups_.FindByWindow(window)) {
            SwitchTo(own->id, 0);
        }
    }
    ScheduleRefresh();
}

void App::SwitchTo(GroupId group, std::size_t index, HWND slot_source) {
    Group* target_group = groups_.Find(group);
    if (target_group == nullptr || index >= target_group->windows.size()) {
        return;
    }
    const std::vector<HWND> windows = target_group->windows;
    const HWND target = windows[index];
    if (slot_source == nullptr && target_group->active < windows.size() &&
        target_group->active != index) {
        slot_source = windows[target_group->active];
    }
    LogLine(L"switch group=%llu index=%zu target=%p slot=%p", static_cast<unsigned long long>(group),
            index, static_cast<void*>(target), static_cast<void*>(slot_source));

    RestoreHidden(target);
    if (IsIconic(target) != FALSE) {
        ShowWindow(target, SW_RESTORE);
    }
    if (Settings::Get().match_window_frame && slot_source != nullptr) {
        MatchWindowFrame(slot_source, target);
    }
    // Hide first, activate last: minimizing the previously active window would
    // otherwise hand the foreground to whatever window is next in the z-order.
    for (std::size_t i = 0; i < windows.size(); ++i) {
        if (i != index) {
            HideWindow(windows[i]);
        }
    }
    ForceForeground(target);
    pending_foreground_ = target;
    focus_retries_ = 0;
    SetTimer(msg_hwnd_, kFocusTimer, 90, nullptr);
    if (Group* current = groups_.Find(group)) {
        current->active = index;
    }
    ScheduleRefresh();
}

void App::HideWindow(HWND hwnd) {
    if (hwnd == nullptr || !IsWindow(hwnd) || hidden_.count(hwnd) != 0) {
        return;
    }
    if (Settings::Get().hide_mode == HideMode::kMinimize) {
        ShowWindow(hwnd, SW_MINIMIZE);
    } else {
        RECT rect{};
        if (GetWindowRect(hwnd, &rect) == FALSE) {
            return;
        }
        saved_rects_[hwnd] = rect;
        SetWindowPos(hwnd, nullptr, -32000, -32000, rect.right - rect.left, rect.bottom - rect.top,
                     SWP_NOZORDER | SWP_NOACTIVATE);
    }
    hidden_.insert(hwnd);
}

void App::RestoreHidden(HWND hwnd) {
    auto hidden = hidden_.find(hwnd);
    if (hidden == hidden_.end()) {
        return;
    }
    if (Settings::Get().hide_mode == HideMode::kMinimize) {
        if (IsIconic(hwnd) != FALSE) {
            ShowWindow(hwnd, SW_RESTORE);
        }
    } else {
        auto saved = saved_rects_.find(hwnd);
        if (saved != saved_rects_.end()) {
            const RECT rect = saved->second;
            SetWindowPos(hwnd, nullptr, rect.left, rect.top, rect.right - rect.left,
                         rect.bottom - rect.top, SWP_NOZORDER | SWP_NOACTIVATE);
        }
    }
    saved_rects_.erase(hwnd);
    hidden_.erase(hidden);
}

void App::RestoreAllHidden() {
    std::vector<HWND> targets(hidden_.begin(), hidden_.end());
    for (HWND hwnd : targets) {
        RestoreHidden(hwnd);
    }
}

void App::RestoreAll() {
    RestoreAllHidden();
    overlays_.clear();
    groups_.DissolveAll();
    title_cache_.clear();
    dirty_titles_.clear();
    RefreshNow();
}

void CALLBACK App::WinEventProc(HWINEVENTHOOK, DWORD event, HWND hwnd, LONG id_object, LONG,
                                DWORD, DWORD) {
    App& app = App::Instance();
    switch (event) {
        case EVENT_OBJECT_LOCATIONCHANGE:
        case EVENT_OBJECT_NAMECHANGE:
            if (hwnd == nullptr || id_object != OBJID_WINDOW) {
                return;
            }
            // Unknown windows only need attention when they first appear; ignoring
            // them here keeps tooltip and menu chatter out of the refresh path.
            if (app.groups_.FindByWindow(hwnd) == nullptr) {
                return;
            }
            if (event == EVENT_OBJECT_NAMECHANGE) {
                app.dirty_titles_.insert(hwnd);
            }
            app.ScheduleRefresh();
            return;
        case EVENT_SYSTEM_FOREGROUND:
        case EVENT_OBJECT_CREATE:
        case EVENT_OBJECT_DESTROY:
        case EVENT_OBJECT_SHOW:
        case EVENT_OBJECT_HIDE:
        case EVENT_OBJECT_CLOAKED:
        case EVENT_OBJECT_UNCLOAKED:
            app.ScheduleRefresh();
            return;
        default:
            return;
    }
}
