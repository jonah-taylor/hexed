const std = @import("std");
const Cursor = @import("cursor").Cursor;
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

        var term_sz = self.term.getSize();
        var prev_term_sz = term_sz;

        try self.winman.drawWins();
        self.term.flush();

        var key: u8 = '.';
        mainloop: while (true) {
            key = try self.term.getch();
            try switch (key) {
                'h' => {
                    switch (self.cur_state) {
                        // .normal => self.winman.newWin(Direction.left) catch {},
                        .resize => try self.winman.resizeWin(Direction.left, self.winman.win_idx, true),
                        else => {}
                    }
                },
                'H' => self.winman.setWinFromDir(Direction.left),
                'j' => {
                    switch (self.cur_state) {
                        // .normal => self.winman.newWin(Direction.down) catch {},
                        .resize => try self.winman.resizeWin(Direction.down, self.winman.win_idx, true),
                        else => {}
                    }
                },
                'J' => self.winman.setWinFromDir(Direction.down),
                'k' => {
                    switch (self.cur_state) {
                        // .normal => self.winman.newWin(Direction.up) catch {},
                        .resize => try self.winman.resizeWin(Direction.up, self.winman.win_idx, true),
                        else => {}
                    }
                },
                'K' => self.winman.setWinFromDir(Direction.up),
                'l' => {
                    switch (self.cur_state) {
                        // .normal => self.winman.newWin(Direction.right) catch {},
                        .resize => try self.winman.resizeWin(Direction.right, self.winman.win_idx, true),
                        else => {}
                    }
                },
                'L' => self.winman.setWinFromDir(Direction.right),
                'd' => {
                    if (!try self.winman.rmWin())
                        break :mainloop;
                    try self.term.clear();
                },
                'w' => {
                    key = try self.term.getch();
                    switch (key) {
                        'h' => self.winman.newWin(Direction.left) catch {},
                        'j' => self.winman.newWin(Direction.down) catch {},
                        'k' => self.winman.newWin(Direction.up) catch {},
                        'l' => self.winman.newWin(Direction.right) catch {},
                        'r' => {
                            if (self.cur_state == .resize) {
                                self.cur_state = .normal;
                            } else {
                                self.cur_state = .resize;
                            }
                        },
                        else => {}
                    }
                },
                else => {}
            };

            if (self.cur_state == .resize) {
                try self.term.clear();
                try self.term.setRed();
            }

            term_sz = self.term.getSize();
            if (term_sz.cols != prev_term_sz.cols or term_sz.rows != prev_term_sz.rows) {
                try self.term.clear();
                const win = &self.winman.wins[self.winman.win_idx orelse return];
                const cursor = &win.cursor;
                try self.term.moveCursorTo(
                    self.term.fixedFromPercY(win.y1) + cursor.y,
                    win.x1 + cursor.x);
            }
            prev_term_sz = term_sz;

            try self.winman.drawWins();

            if (self.cur_state == .resize)
                try self.term.colorReset();

            self.term.flush();

        }
    }
};
