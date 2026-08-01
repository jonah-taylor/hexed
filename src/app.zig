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
        try self.term.clearTerminal();

        // first window
        try self.winman.newWindow(Direction.up); // first window

        try self.winman.drawWindows();
        self.term.flush();

        var key: u8 = '.';
        mainloop: while (true) {
            key = try self.term.getch();
            try switch (key) {
                'q' => break :mainloop,

                'h' => try self.winman.newWindow(Direction.left),
                'j' => try self.winman.newWindow(Direction.down),
                'k' => try self.winman.newWindow(Direction.up),
                'l' => try self.winman.newWindow(Direction.right),
                'H' => self.winman.changeCurWindow(Direction.left),
                'J' => self.winman.changeCurWindow(Direction.down),
                'K' => self.winman.changeCurWindow(Direction.up),
                'L' => self.winman.changeCurWindow(Direction.right),

                // 'w' => try self.changeCurWindow(),
                else => {}
            };

            try self.winman.drawWindows();
            self.term.flush();

        }
    }

    // fn changeCurWindow(self: *Self) !void {
    //     const key = try self.term.getch();
    //     try switch (key) {
    //         else => {},
    //     };
    // }
};
