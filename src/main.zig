const std = @import("std");

const win = struct {
    usingnamespace @import("win32").everything;
    usingnamespace @import("win32").zig;

    // Custom undocumented decls, thanks stackoverflow!
    // https://stackoverflow.com/questions/61869347/control-windows-10s-power-mode-programmatically
    pub extern "powrprof" fn PowerSetActiveOverlayScheme(
        OverlaySchemeGuid: ?*const Guid,
    ) callconv(std.os.windows.WINAPI) u32;
};
const Guid = win.Guid;

pub fn main() !void {
    // Hello world messagebox
    _ = win.MessageBoxA(
        null,
        "Hallo wereld 💩",
        "Ik ben een schermpje :)",
        win.MB_OK,
    );

    // Setup different powermode guid's
    const batt_guid = comptime Guid.initString("961cc777-2547-4f9d-8174-7d86181b8a7a");
    const balc_guid = comptime Guid.initString("00000000-0000-0000-0000-000000000000");
    const perf_guid = comptime Guid.initString("ded574b5-45a0-4f42-8737-46345c09c238");
    _ = batt_guid;
    _ = balc_guid;
    // Try set powermode to high performance
    _ = win.PowerSetActiveOverlayScheme(&perf_guid);
    const err_code = win.PowerSetActiveOverlayScheme(&perf_guid);

    // Setup stdout for printing to console
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Executed with return code: {}\n", .{err_code});
    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
