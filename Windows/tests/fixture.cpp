#define UNICODE
#define _UNICODE
#include <windows.h>
#include <string_view>

LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM word, LPARAM value)
{
    if (message == WM_CLOSE) { DestroyWindow(window); return 0; }
    if (message == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcW(window, message, word, value);
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR arguments, int show)
{
    if (std::wstring_view(arguments) == L"--exit-early") return 0;
    WNDCLASSW type{};
    type.lpfnWndProc = WindowProcedure;
    type.hInstance = instance;
    type.lpszClassName = L"WindowsRuntimeFixture";
    if (!RegisterClassW(&type)) return 1;
    auto window = CreateWindowW(type.lpszClassName, L"Windows Runtime Fixture",
                               WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
                               480, 320, nullptr, nullptr, instance, nullptr);
    if (!window) return 2;
    ShowWindow(window, show);
    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    return static_cast<int>(message.wParam);
}
