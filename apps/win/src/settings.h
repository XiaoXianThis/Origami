#pragma once

enum class HideMode {
    kMinimize = 0,
    kMoveOffscreen = 1,
};

struct Settings {
    HideMode hide_mode = HideMode::kMoveOffscreen;
    bool restore_on_exit = true;
    bool enabled = true;
    // When switching inside a group, move the incoming window into the frame of
    // the outgoing one.
    bool match_window_frame = true;

    static Settings& Get();

    void Load();
    void Save() const;
};
