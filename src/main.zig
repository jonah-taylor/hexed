const std = @import("std");
const App = @import("app").App;
const Terminal = @import("terminal").Terminal;

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;
    const alloc = std.heap.page_allocator;

    var term = Terminal.init(stdout);
    var app = App.init(stdout, alloc, &term);

    try app.run();
}
