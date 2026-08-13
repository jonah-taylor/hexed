const std = @import("std");

pub fn build(b : *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main = b.createModule(.{
        .root_source_file = b.path("./src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const app = b.createModule(.{
        .root_source_file = b.path("./src/app.zig"),
        .target = target,
        .optimize = optimize,
    });

    const terminal = b.createModule(.{
        .root_source_file = b.path("./src/terminal.zig"),
        .target = target,
        .optimize = optimize,
    });

    const window = b.createModule(.{
        .root_source_file = b.path("./src/window.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cursor = b.createModule(.{
        .root_source_file = b.path("./src/cursor.zig"),
        .target = target,
        .optimize = optimize,
    });

    const winman = b.createModule(.{
        .root_source_file = b.path("./src/winman.zig"),
        .target = target,
        .optimize = optimize,
    });

    main.addImport("app", app);
    main.addImport("terminal", terminal);

    app.addImport("cursor", cursor);
    app.addImport("terminal", terminal);
    app.addImport("window", window);
    app.addImport("winman", winman);

    window.addImport("cursor", cursor);
    window.addImport("terminal", terminal);

    winman.addImport("cursor", cursor);
    winman.addImport("terminal", terminal);
    winman.addImport("window", window);

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = main,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_cmd.step);
}
