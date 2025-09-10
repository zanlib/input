const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const input_mod = b.addModule("input", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "keyboard-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/keyboard.zig"),
            .imports = &.{.{ .name = "input", .module = input_mod }},
            .target = target,
        }),
        .optimize = optimize,
    });

    switch (target.result.os.tag) {
        .windows => {
            exe.linkLibC();
        },
        .macos => {
            exe.linkFramework("Carbon");
        },
        .linux => {
            exe.linkLibC();
            exe.linkSystemLibrary("input");
            exe.linkSystemLibrary("udev");
        },
        else => @panic("Unsupported OS"),
    }

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
