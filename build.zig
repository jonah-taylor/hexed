const std = @import("std");

pub fn build(b : *std.Build) void {

    const app = b.createModule(.{
        .root_source_file = b.path("./src/app.zig"),
    });

    const terminal = b.createModule(.{
        .root_source_file = b.path("./src/terminal.zig"),
    });

    const window = b.createModule(.{
        .root_source_file = b.path("./src/window.zig"),
    });

    const cursor = b.createModule(.{
        .root_source_file = b.path("./src/cursor.zig"),
    });

    app.addImport("terminal", terminal);
    app.addImport("window", window);

    terminal.addImport("window", window);

    window.addImport("terminal", terminal);
    window.addImport("cursor", cursor);

    const main = b.addExecutable(.{
        .name = "math",
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/main.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    main.root_module.addImport("app", app);
    main.root_module.addImport("terminal", terminal);
    main.root_module.addImport("window", window);

    b.installArtifact(main);

    const run_cmd = b.addRunArtifact(main);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_cmd.step);
}
