const std = @import("std");
const Terminal = @import("terminal").Terminal;
const Window = @import("window").Window;

pub const App = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    stdout: *std.Io.Writer,
    term: Terminal,

    pub fn init(stdout: *std.Io.Writer, alloc: std.mem.Allocator) Self {
        return Self{
            .alloc = alloc,
            .stdout = stdout,
            .term = Terminal.init(stdout),
        };
    }

    pub fn run(self: *Self) !void {
        try self.term.enableRaw();
        defer self.term.disableRaw();

        self.term.clearTerminal();

        const grid = try self.term.getSize();
        var win: *Window = self.term.newWindow(0, 0, grid.rows, grid.cols).?;
        try win.drawBorder();

        self.term.flush();

        // main loop
        while (true) {
            const c = try self.term.getch();
            if (c == 'q') break;

            // if (self.term.cur_window) |window| {
                // window.cursor
            // }

            self.term.flush();
        }
    }

};
