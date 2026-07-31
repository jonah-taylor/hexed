const std = @import("std");
const Terminal = @import("terminal").Terminal;
const Winman = @import("winman").Winman;
const Direction = @import("winman").Direction;
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
        // setup
        try self.term.enableRaw();
        defer self.term.disableRaw();

        self.winman.term = &self.term;
        self.term.clearTerminal();

        // first window
        self.winman.newWindow(Direction.up); // first window

        // main loop
        var c: u8 = 'u';
        while (true) {
            // try self.stdout.print("{c}", .{c});
            switch (c) {
                'h' => self.winman.newWindow(Direction.left),
                'j' => self.winman.newWindow(Direction.down),
                'k' => self.winman.newWindow(Direction.up),
                'l' => self.winman.newWindow(Direction.right),
                else => {}
            }
            try self.winman.drawWindows();
            self.term.flush();

            if (c == 'q') break;
            c = try self.term.getch();
        }
    }
};
