#include <windows.h>

#include "app.h"

int APIENTRY wWinMain(HINSTANCE instance, HINSTANCE, LPWSTR, int show_cmd) {
    return App::Instance().Run(instance, show_cmd);
}
