#include "log.h"

#include <windows.h>

#include <cstdarg>
#include <cstdio>
#include <string>

namespace {

std::wstring LogPath() {
    wchar_t buffer[MAX_PATH]{};
    const DWORD length = GetEnvironmentVariableW(L"ORIGAMI_WIN_LOG", buffer, MAX_PATH);
    if (length == 0 || length >= MAX_PATH) {
        return {};
    }
    return buffer;
}

}  // namespace

void LogLine(const wchar_t* format, ...) {
    static const std::wstring path = LogPath();
    if (path.empty()) {
        return;
    }
    SYSTEMTIME now{};
    GetLocalTime(&now);

    wchar_t message[1024]{};
    va_list args;
    va_start(args, format);
    _vsnwprintf_s(message, _TRUNCATE, format, args);
    va_end(args);

    FILE* file = nullptr;
    if (_wfopen_s(&file, path.c_str(), L"a, ccs=UTF-8") != 0 || file == nullptr) {
        return;
    }
    fwprintf(file, L"%02d:%02d:%02d.%03d %s\n", now.wHour, now.wMinute, now.wSecond,
             now.wMilliseconds, message);
    fclose(file);
}
