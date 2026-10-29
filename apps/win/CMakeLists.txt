cmake_minimum_required(VERSION 3.20)

project(origami_win LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_compile_definitions(
    WINVER=0x0A00
    _WIN32_WINNT=0x0A00
    UNICODE
    _UNICODE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
)

if(MSVC)
    add_compile_options(/W4 /permissive- /utf-8 /EHsc /Zc:__cplusplus)
    # Static CRT: the exe must not need a VC++ redistributable.
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

set(OUT_DIR "$ENV{WOK_OUT}")
if(NOT OUT_DIR)
    set(OUT_DIR "${CMAKE_BINARY_DIR}/bin")
endif()

add_executable(origami WIN32
    src/main.cpp
    src/app.cpp
    src/group_store.cpp
    src/log.cpp
    src/drag_visuals.cpp
    src/overlay_window.cpp
    src/settings.cpp
    src/tab_bar.cpp
    src/window_enum.cpp
)

target_include_directories(origami PRIVATE src)
target_link_libraries(origami PRIVATE user32 gdi32 dwmapi shell32 advapi32 ole32 d2d1 dwrite)

set_target_properties(origami PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${OUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${OUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${OUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${OUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "${OUT_DIR}"
)
