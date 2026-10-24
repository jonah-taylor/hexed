const std = @import("std");
const term_ops = @import("terminal.zig");

const app_ops = @import("app.zig");
const App = app_ops.App;

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    const alloc = std.heap.page_allocator;

    term_ops.enterAltScreen(stdout) catch {};
    defer term_ops.exitAltScreen(stdout) catch {};

    const init_termios = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
    defer term_ops.setTermios(init_termios) catch {};
    errdefer term_ops.setTermios(init_termios) catch {};

    const raw_termios = term_ops.createRawTermiosFrom(init_termios);
    try term_ops.setTermios(raw_termios);

    var io = init.io;
    var app = App.init(&io, init_termios, raw_termios, stdout, alloc);

    try app_ops.runApp(&app);
}
