const std = @import("std");
const term = @import("./terminal.zig");

const App = @import("./app.zig").App;

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    const alloc = std.heap.page_allocator;

    const init_termios = try std.posix.tcgetattr(std.posix.STDIN_FILENO);
    const raw_termios = term.createRawTermiosFrom(init_termios);

    term.setTermios(raw_termios);
    defer term.setTermios(init_termios);

    var app = App.init(stdout, alloc);

    try app.run();
}
