#pragma once

#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "group_store.h"
#include "drag_visuals.h"
#include "settings.h"
#include "tab_bar.h"

class OverlayWindow;

class App {
public:
    static App& Instance();

    int Run(HINSTANCE instance, int show_cmd);

    // Called by overlays.
    void OnTabClicked(GroupId group, int index);
    void OnTabDragBegan(GroupId group, int index);
    void OnTabDragMoved(GroupId group, int index, POINT screen);
    void OnTabDropped(GroupId group, int index, POINT screen);
    void OnTabDragCancelled();

    void ScheduleRefresh();
    void RefreshNow();
    void MarkTitleDirty(HWND hwnd);

private:
    App() = default;

    LRESULT HandleMessage(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
    static LRESULT CALLBACK MessageProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
    static void CALLBACK WinEventProc(HWINEVENTHOOK hook, DWORD event, HWND hwnd, LONG id_object,
                                      LONG id_child, DWORD thread, DWORD time);

    void CreateMessageWindow();
    void AddTrayIcon();
    void RemoveTrayIcon();
    void ShowTrayMenu();
    void InstallEventHooks();
    void RemoveEventHooks();

    OverlayWindow* OverlayFor(GroupId group, bool create);
    std::wstring TitleFor(HWND hwnd);

    struct DropResolution {
        GroupId group = 0;
        bool on_bar = false;
        bool on_window = false;
        RECT frame{};
        float scale = 1.0f;
    };
    DropResolution ResolveDrop(GroupId source, POINT screen);

    void SwitchTo(GroupId group, std::size_t index, HWND slot_source = nullptr);
    void HideWindow(HWND hwnd);
    void RestoreHidden(HWND hwnd);
    void RestoreAllHidden();
    void RestoreAll();

    HINSTANCE instance_ = nullptr;
    HWND msg_hwnd_ = nullptr;
    UINT_PTR refresh_timer_ = 0;
    std::vector<HWINEVENTHOOK> hooks_;

    GroupStore groups_;
    std::unordered_map<GroupId, std::unique_ptr<OverlayWindow>> overlays_;
    std::unordered_map<HWND, RECT> saved_rects_;
    std::set<HWND> hidden_;
    std::unordered_map<HWND, std::wstring> title_cache_;
    std::set<HWND> dirty_titles_;
    std::set<HWND> known_windows_;

    TabBarRenderer renderer_;
    DragVisuals drag_visuals_;
    GroupId drag_group_ = 0;
    int drag_index_ = -1;
    bool dark_ = false;
    bool shutting_down_ = false;
    std::size_t last_group_count_ = 0;
    std::size_t last_window_count_ = 0;
    HWND pending_foreground_ = nullptr;
    int focus_retries_ = 0;
    NOTIFYICONDATAW tray_{};
};
