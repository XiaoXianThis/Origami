#include "settings.h"

#include <windows.h>

#include <string>

namespace {

std::wstring SettingsPath() {
    wchar_t appdata[MAX_PATH]{};
    if (GetEnvironmentVariableW(L"APPDATA", appdata, MAX_PATH) == 0) {
        return {};
    }
    std::wstring dir = appdata;
    dir += L"\\Origami";
    CreateDirectoryW(dir.c_str(), nullptr);
    return dir + L"\\settings.ini";
}

}  // namespace

Settings& Settings::Get() {
    static Settings instance = [] {
        Settings settings;
        settings.Load();
        return settings;
    }();
    return instance;
}

void Settings::Load() {
    const std::wstring path = SettingsPath();
    if (path.empty()) {
        return;
    }
    const int mode = GetPrivateProfileIntW(L"general", L"hide_mode", static_cast<int>(hide_mode), path.c_str());
    hide_mode = mode == static_cast<int>(HideMode::kMinimize) ? HideMode::kMinimize : HideMode::kMoveOffscreen;
    enabled = GetPrivateProfileIntW(L"general", L"enabled", enabled ? 1 : 0, path.c_str()) != 0;
    restore_on_exit = GetPrivateProfileIntW(L"general", L"restore_on_exit", restore_on_exit ? 1 : 0, path.c_str()) != 0;
    match_window_frame = GetPrivateProfileIntW(L"general", L"match_window_frame", match_window_frame ? 1 : 0, path.c_str()) != 0;
}

void Settings::Save() const {
    const std::wstring path = SettingsPath();
    if (path.empty()) {
        return;
    }
    WritePrivateProfileStringW(L"general", L"hide_mode", std::to_wstring(static_cast<int>(hide_mode)).c_str(), path.c_str());
    WritePrivateProfileStringW(L"general", L"enabled", enabled ? L"1" : L"0", path.c_str());
    WritePrivateProfileStringW(L"general", L"restore_on_exit", restore_on_exit ? L"1" : L"0", path.c_str());
    WritePrivateProfileStringW(L"general", L"match_window_frame", match_window_frame ? L"1" : L"0", path.c_str());
}
