const std = @import("std");

const win = struct {
    usingnamespace @import("win32").everything;
    usingnamespace @import("win32").zig;

    // Custom undocumented decls, thanks stackoverflow!
    // https://stackoverflow.com/questions/61869347/control-windows-10s-power-mode-programmatically
    pub extern "powrprof" fn PowerSetActiveOverlayScheme(
        OverlaySchemeGuid: ?*const Guid,
    ) callconv(std.os.windows.WINAPI) u32;

    pub extern "powrprof" fn PowerGetActualOverlayScheme(
        ActualOverlayGuid: ?*Guid,
    ) callconv(std.os.windows.WINAPI) u32;
};

const Guid = win.Guid;

const PowerMode = enum {
    efficiency,
    balanced,
    performance,
};

const powermodes = std.EnumArray(PowerMode, Guid).init(
    .{
        .efficiency = Guid.initString("961cc777-2547-4f9d-8174-7d86181b8a7a"),
        .balanced = Guid.initString("00000000-0000-0000-0000-000000000000"),
        .performance = Guid.initString("ded574b5-45a0-4f42-8737-46345c09c238"),
    },
);

fn set_power_mode(mode: PowerMode) !void {
    const err_code = win.PowerSetActiveOverlayScheme(&powermodes.get(mode));
    if (err_code != 0) return error.SetModePowerFail;
}

fn get_power_mode() !PowerMode {
    var guid: Guid = undefined;
    const err_code = win.PowerGetActualOverlayScheme(&guid);
    if (err_code != 0) return error.GetModePowerFail;

    // making a local copy due to lack of const iterator :/
    var powermodes_local = powermodes;
    var iter = powermodes_local.iterator();
    while (iter.next()) |guid_entry| {
        if (std.meta.eql(guid_entry.value.*.Bytes, guid.Bytes)) return guid_entry.key;
    }

    return error.UnkownMode;
}

fn winapi_window_test() void {
    // Hello world messagebox
    _ = win.MessageBoxA(
        null,
        "Hallo wereld 💩",
        "Ik ben een schermpje :)",
        win.MB_OK,
    );
}

fn asSzTip(comptime str: []const u8) [128]u8 {
    var szTip: [128]u8 = undefined;
    @memcpy(szTip[0..str.len], str);
    szTip[str.len] = 0;
    return szTip;
}

fn make_notification_icon(handle: win.HWND) !void {
    var nid: win.NOTIFYICONDATAA = .{
        .cbSize = @sizeOf(win.NOTIFYICONDATAA),
        .hWnd = handle,
        .uID = 1,
        .uFlags = .{ .MESSAGE = 1, .TIP = 1, .ICON = 1 },
        .uCallbackMessage = win.WM_USER + 1,
        .hIcon = win.LoadIconW(null, win.IDI_EXCLAMATION).?,
        .szTip = asSzTip("Wow, a notification icon!"),

        // undefined fields
        .dwState = undefined,
        .dwStateMask = undefined,
        .szInfo = undefined,
        .szInfoTitle = undefined,
        .Anonymous = undefined,
        .dwInfoFlags = undefined,
        .guidItem = undefined,
        .hBalloonIcon = undefined,
    };

    if (win.Shell_NotifyIconA(win.NIM_ADD, &nid) != 0) {
        // return print_and_handle_error();
        // return error.AddNotificationIconFail;
    }
}

fn wndproc_impl(hWnd: win.HWND, uMsg: u32, wParam: win.WPARAM, lParam: win.LPARAM) callconv(@import("std").os.windows.WINAPI) win.LRESULT {
    const WM_TRAYICON_MSG = 1025;

    std.debug.print("Message: {}\n", .{uMsg});

    blk: {
        switch (uMsg) {
            // Handle the notification icon message
            WM_TRAYICON_MSG => {
                std.debug.print("Notification icon message: {}\n", .{lParam});
                const message = switch (lParam) {
                    win.WM_LBUTTONUP => "Left click on the notification icon",
                    win.WM_RBUTTONUP => "Right click on the notification icon",
                    else => break :blk,
                };
                _ = win.MessageBoxA(
                    hWnd,
                    message,
                    "Notification icon",
                    win.MB_OK,
                );
            },
            win.WM_DESTROY => {
                std.posix.exit(0);
            },
            else => {},
        }
    }

    return win.DefWindowProcA(hWnd, uMsg, wParam, lParam);
}

fn print_and_handle_error() std.posix.UnexpectedError {
    const err = std.os.windows.kernel32.GetLastError();
    return std.os.windows.unexpectedError(err);
}

fn make_main_window() !?win.HWND {
    const hInstance = win.GetModuleHandleA(null);
    const className = "main";

    var wc: win.WNDCLASSA = .{
        .lpfnWndProc = wndproc_impl,
        .hInstance = hInstance,
        .lpszClassName = className,
        .hCursor = win.LoadCursorW(null, win.IDC_ARROW).?,
        .hbrBackground = win.GetStockObject(win.WHITE_BRUSH),

        // undefined fields
        .lpszMenuName = null,
        .hIcon = null,
        .style = .{},
        .cbClsExtra = 0,
        .cbWndExtra = 0,
    };

    if (win.RegisterClassA(&wc) == 0) return print_and_handle_error();

    const hWnd = win.CreateWindowExA(
        .{},
        className,
        "Main window",
        .{ // TODO: Make invisable and add a way to exit the application
            .VISIBLE = 1,
            .SYSMENU = 1,
        },
        win.CW_USEDEFAULT,
        win.CW_USEDEFAULT,
        200,
        200,
        null,
        null,
        hInstance,
        null,
    );

    return hWnd;
}

pub fn main() !void {
    // Setup stdout for printing to console
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // try changing the powermode to performance
    try stdout.print("Power mode before: {}\n", .{try get_power_mode()});
    try set_power_mode(.performance);
    try stdout.print("Power mode after: {}\n", .{try get_power_mode()});
    try bw.flush();

    // try making a notification icon
    const handle = (try make_main_window()).?;
    try make_notification_icon(handle);

    // Run the message loop
    var msg: win.MSG = undefined;
    while (win.GetMessageA(&msg, null, 0, 0) != 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageA(&msg);
    }
}
