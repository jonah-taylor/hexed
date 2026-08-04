const std = @import("std");
const Cursor = @import("cursor").Cursor;
const Terminal = @import("terminal").Terminal;
const Window = @import("window").Window;

pub const Direction = enum {
    up,
    down,
    left,
    right,
};

pub const WinMan = struct {
    const Self = @This();

    stdout: *std.Io.Writer,
    term: *Terminal,
    wins: [16]Window,
    wins_len: usize,
    win_idx: ?usize,

    pub fn init(stdout: *std.Io.Writer) Self {
        return Self{
            .stdout = stdout,
            .term = undefined,
            .wins = undefined,
            .wins_len = 0,
            .win_idx = null,
        };
    }

    pub fn drawWins(self: *Self) !void {
        try self.term.saveCursorPos();
        for (0..self.wins_len) |i| {
            try self.wins[i].drawBorder();
        }
        try self.term.loadCursorPos();
    }

    pub fn getWinIdxAt(self: *Self, x_loc: u16, y_loc: u16) ?usize {
        for (0..self.wins_len) |i| {
            if (self.wins[i].hasCoord(x_loc, y_loc)) {
                return i;
            }
        }
        return null;
    }

    pub fn newWin(self: *Self, dir: Direction) !void {
        if (self.wins_len >= self.wins.len) return;

        var x_loc: u16 = undefined;
        var y_loc: u16 = undefined;
        var rows: u16 = undefined;
        var cols: u16 = undefined;

        if (self.win_idx) |idx| {
            const win: *Window = &self.wins[idx];
            x_loc = win.x_loc;
            y_loc = win.y_loc;
            rows = win.rows;
            cols = win.cols;
            switch (dir) {
                .up => {
                    rows /= 2;
                    win.y_loc += rows;
                    win.rows = (win.rows + 1) / 2;
                },
                .down => {
                    rows /= 2;
                    win.rows = (win.rows + 1) / 2;
                    y_loc = win.y_loc + win.rows;
                },
                .left => {
                    cols /= 2;
                    win.x_loc += cols;
                    win.cols = (win.cols + 1) / 2;
                },
                .right => {
                    cols /= 2;
                    win.cols = (win.cols + 1) / 2;
                    x_loc = win.x_loc + win.cols;
                },
            }
        } else { // define first window
            x_loc = 0;
            y_loc = 0;
            const term_sz = self.term.getSize();
            rows = term_sz.rows;
            cols = term_sz.cols;
        }
        self.wins[self.wins_len] = Window.init(self.stdout, self.term, x_loc, y_loc, rows, cols);
        self.wins_len += 1;
        try self.setWin(self.wins_len - 1);
    }

    pub fn setWin(self: *Self, new_idx: ?usize) !void {
        self.win_idx = new_idx;
        const cur: *Window = &self.wins[self.win_idx orelse return];
        const cursor: *Cursor = &cur.cursor;
        try self.term.moveCursorTo(cur.y_loc + cursor.y_loc, cur.x_loc + cursor.x_loc);
    }

    pub fn getWinIdxsInDirOfWin(self: *Self, dir: Direction, base_idx: usize, out: *[self.wins.len]usize) ?usize {
        const win: *Window = &self.wins[base_idx];
        var out_idx: usize = 0;

        // get first window
        var side_idx: usize = self.getWinIdxInDir(dir, win.x_loc, win.y_loc) orelse {
            return null;
        };

        out[out_idx] = side_idx;
        var side_win: *Window = &self.wins[out[out_idx]];
        out_idx += 1;

        // iterate over side windows
        sideiter: switch (dir) {
            .up, .down => {
                if (side_win.x_loc != win.x_loc or side_win.cols > win.cols) return null;
                if (side_win.x_loc + side_win.cols == win.x_loc + win.cols) break :sideiter;
                while (true) {
                    const y: u16 = if (dir == .up) side_win.y_loc + side_win.rows - 1 else side_win.y_loc;

                    side_idx = self.getWinIdxInDir(.right, side_win.x_loc, y) orelse break;
                    out[out_idx] = side_idx;
                    side_win = &self.wins[side_idx];
                    out_idx += 1;

                    if (side_win.x_loc + side_win.cols == win.x_loc + win.cols) break;
                    if (side_win.x_loc + side_win.cols > win.x_loc + win.cols) return null;
                }
            },
            .left, .right => {
                if (side_win.y_loc != win.y_loc or side_win.rows > win.rows) return null;
                if (side_win.y_loc + side_win.rows == win.y_loc + win.rows) break :sideiter;
                while (true) {
                    const x: u16 = if (dir == .left) side_win.x_loc + side_win.cols - 1 else side_win.x_loc;

                    side_idx = self.getWinIdxInDir(.down, x, side_win.y_loc) orelse break;
                    out[out_idx] = side_idx;
                    side_win = &self.wins[side_idx];
                    out_idx += 1;

                    if (side_win.y_loc + side_win.rows == win.y_loc + win.rows) break;
                    if (side_win.y_loc + side_win.rows > win.y_loc + win.rows) return null;
                }
            },
        }

        return out_idx;
    }

    pub fn delSel(self: *Self) !void {
        const food_idx: usize = self.win_idx orelse return;
        const food: *Window = &self.wins[food_idx];

        var consumers: usize = undefined;
        var buf: [self.wins.len]usize = undefined;
        var dir: Direction = undefined;

        for (std.enums.values(Direction)) |d| {
            dir = d;
            consumers = self.getWinIdxsInDirOfWin(dir, food_idx, &buf) orelse continue;
            break;
        } else return;

        switch (dir) {
            .up => for (0..consumers) |i| {
                self.wins[buf[i]].rows += food.rows;
            },
            .down => for (0..consumers) |i| {
                self.wins[buf[i]].rows += food.rows;
                self.wins[buf[i]].y_loc = food.y_loc;
            },
            .left => for (0..consumers) |i| {
                self.wins[buf[i]].cols += food.cols;
            },
            .right => for (0..consumers) |i| {
                self.wins[buf[i]].cols += food.cols;
                self.wins[buf[i]].x_loc = food.x_loc;
            },
        }

        self.wins[food_idx] = self.wins[self.wins_len - 1];
        self.wins_len -= 1;
        try self.setWin(if (buf[0] == self.wins_len) food_idx else buf[0]);
    }

    pub fn selInDir(self: *Self, dir: Direction) !void {
        const win: *Window = &self.wins[self.win_idx orelse return];
        const cursor: *Cursor = &win.cursor;
        const win_idx: usize =
            self.getWinIdxInDir(dir, win.x_loc + cursor.x_loc, win.y_loc + cursor.y_loc)
            orelse return;

        try self.setWin(win_idx);
    }

    fn getWinIdxInDir(self: *Self, dir: Direction, x_loc: u16, y_loc: u16) ?usize {
        const coord_idx = self.getWinIdxAt(x_loc, y_loc) orelse return null;
        const win: *Window = &self.wins[coord_idx];
         return switch (dir) {
            .up => return self.getWinIdxAt(x_loc, win.y_loc -% 1),
            .down => self.getWinIdxAt(x_loc, win.y_loc + win.rows),
            .left => self.getWinIdxAt(win.x_loc -% 1, y_loc),
            .right => self.getWinIdxAt(win.x_loc + win.cols, y_loc),
        };
    }
};
