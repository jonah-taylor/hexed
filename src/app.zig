const std = @import("std");
const Terminal = @import("terminal").Terminal;
const WinMan = @import("winman").WinMan;
const Direction = @import("winman").Direction;
const Window = @import("window").Window;

// TODO:
// update keymappings for cursor and window navigation
// add shrinking resize and rotation keybinds

pub const App = struct {
    const Self = @This();

    const state = enum {
        normal,
        resize,
    };

    alloc: std.mem.Allocator,
    stdout: *std.Io.Writer,
    term: *Terminal,
    winman: WinMan,
    cur_state: state,

    pub fn init(stdout: *std.Io.Writer, alloc: std.mem.Allocator, term: *Terminal) Self {
        return .{
            .alloc = alloc,
            .stdout = stdout,
            .term = term,
            .winman = WinMan.init(stdout, term),
            .cur_state = .normal,
        };
    }

    pub fn run(self: *Self) !void {
        try self.term.enableRaw();
        defer self.term.disableRaw();

        try self.term.clear();

        try self.winman.newWin(Direction.up);

        try self.winman.drawWins();
        self.term.flush();

        var key: u8 = '.';
        mainloop: while (true) {
            key = try self.term.getch();
            try switch (key) {
                'q' => break :mainloop,

                'h' => {
                    switch (self.cur_state) {
                        .normal => self.winman.newWin(Direction.left) catch {},
                        .resize => try self.winman.resizeWin(Direction.left, self.winman.win_idx, true),
                    }
                },
                'j' => {
                    switch (self.cur_state) {
                        .normal => self.winman.newWin(Direction.down) catch {},
                        .resize => try self.winman.resizeWin(Direction.down, self.winman.win_idx, true),
                    }
                },
                'k' => {
                    switch (self.cur_state) {
                        .normal => self.winman.newWin(Direction.up) catch {},
                        .resize => try self.winman.resizeWin(Direction.up, self.winman.win_idx, true),
                    }
                },
                'l' => {
                    switch (self.cur_state) {
                        .normal => self.winman.newWin(Direction.right) catch {},
                        .resize => try self.winman.resizeWin(Direction.right, self.winman.win_idx, true),
                    }
                },
                'H' => self.winman.setWinFromDir(Direction.left),
                'J' => self.winman.setWinFromDir(Direction.down),
                'K' => self.winman.setWinFromDir(Direction.up),
                'L' => self.winman.setWinFromDir(Direction.right),
                'd' => {
                    try self.winman.rmWin();
                    try self.term.clear();
                },
                'r' => {
                    if (self.cur_state == .resize) {
                        self.cur_state = .normal;
                    } else {
                        self.cur_state = .resize;
                    }
                },
                // w = save
                else => {}
            };

            if (self.cur_state == .resize) {
                try self.term.clear();
                try self.term.setRed();
            }

            try self.winman.drawWins();

            if (self.cur_state == .resize)
                try self.term.colorReset();

            self.term.flush();

        }
    }
};
