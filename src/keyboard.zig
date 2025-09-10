const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("input");

pub fn main() !void {
    std.debug.print("Input Testing.\n", .{});
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    while (true) {
        try lib.update();
        // Example: Check specific key (A)
        inline for (std.meta.fields(lib.Key)) |field| {
            const key: lib.Key = @enumFromInt(field.value);
            if (lib.getKeyboardState(key)) {
                try stdout.print("Key {s} is pressed\n", .{lib.getKeyName(key)});
            }
        }
        // sleep
        try bw.flush(); // Don't forget to flush!
        std.time.sleep(100 * std.time.ns_per_ms);
    }

    try bw.flush(); // Don't forget to flush!
}
