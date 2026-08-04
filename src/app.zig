const std = @import("std");
const Terminal = @import("terminal").Terminal;
const WinMan = @import("winman").WinMan;
const Direction = @import("winman").Direction;
const Window = @import("window").Window;

pub const App = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    stdout: *std.Io.Writer,
    term: Terminal,
    winman: WinMan,

    pub fn init(stdout: *std.Io.Writer, alloc: std.mem.Allocator) Self {
        return .{
            .alloc = alloc,
            .stdout = stdout,
            .term = Terminal.init(stdout),
            .winman = WinMan.init(stdout),
        };
    }

    pub fn run(self: *Self) !void {
        try self.term.enableRaw();
        defer self.term.disableRaw();

        self.winman.term = &self.term;
        try self.term.clear();

        try self.winman.newWin(Direction.up);

        try self.winman.drawWins();
        self.term.flush();

        var key: u8 = '.';
        mainloop: while (true) {
            key = try self.term.getch();
            try switch (key) {
                'q' => break :mainloop,

                'h' => try self.winman.newWin(Direction.left),
                'j' => try self.winman.newWin(Direction.down),
                'k' => try self.winman.newWin(Direction.up),
                'l' => try self.winman.newWin(Direction.right),
                'H' => self.winman.selInDir(Direction.left),
                'J' => self.winman.selInDir(Direction.down),
                'K' => self.winman.selInDir(Direction.up),
                'L' => self.winman.selInDir(Direction.right),
                'd' => {
                    try self.winman.delSel();
                    try self.term.clear();
                },
                else => {}
            };

            try self.winman.drawWins();
            self.term.flush();

        }
    }
};
