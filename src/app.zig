const std = @import("std");
const Terminal = @import("terminal").Terminal;
const Winman = @import("winman").Winman;
const Window = @import("window").Window;

pub const App = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    stdout: *std.Io.Writer,
    term: Terminal,
    winman: Winman,

    pub fn init(stdout: *std.Io.Writer, alloc: std.mem.Allocator) Self {
        return .{
            .alloc = alloc,
            .stdout = stdout,
            .term = Terminal.init(stdout),
            .winman = Winman.init(stdout),
        };
    }

    pub fn run(self: *Self) !void {
        try self.term.enableRaw();
        defer self.term.disableRaw();

        self.winman.term = &self.term;
        self.term.clearTerminal();

        // get window
        const grid = try self.term.getSize();
        var win: *Window = self.winman.newWindow(0, 0, grid.rows, grid.cols).?;
        try win.drawBorder();

        try self.term.moveCursorTo(1, 1);

        self.term.flush();

        while (true) {
            const c = try self.term.getch();
            if (c == 'q') break;
            try self.stdout.print("{c}", .{c});

            self.term.flush();
        }
    }

};
