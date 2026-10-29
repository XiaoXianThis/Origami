#pragma once

// Diagnostic log, off unless ORIGAMI_WIN_LOG points at a file. Used while
// debugging window and drag behavior; production runs never open a file.
void LogLine(const wchar_t* format, ...);
