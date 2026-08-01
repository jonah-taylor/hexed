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

pub const Winman = struct {
    const Self = @This();

    stdout: *std.Io.Writer,
    term: *Terminal,
    windows: [16]Window,
    windows_len: usize,
    cur_window: ?*Window,

    pub fn init(stdout: *std.Io.Writer) Self {
        return Self{
            .stdout = stdout,
            .term = undefined,
            .windows = undefined,
            .windows_len = 0,
            .cur_window = null,
        };
    }

    pub fn drawWindows(self: *Self) !void {
        try self.term.saveCursorPos();
        for (0..self.windows_len) |i| {
            try self.windows[i].drawBorder();
        }
        try self.term.loadCursorPos();
    }

    pub fn getWindowWithCoord(self: *Self, x_loc: u16, y_loc: u16) ?*Window {
        for (0..self.windows_len) |i| {
            if (self.windows[i].hasCoord(x_loc, y_loc)) {
                return &self.windows[i];
            }
        }
        return null;
    }

    pub fn newWindow(self: *Self, dir: Direction) !void {
        if (self.windows_len >= self.windows.len) return;

        var x_loc: u16 = undefined;
        var y_loc: u16 = undefined;
        var rows: u16 = undefined;
        var cols: u16 = undefined;

        if (self.cur_window) |cur| {
            x_loc = cur.x_loc;
            y_loc = cur.y_loc;
            rows = cur.rows;
            cols = cur.cols;
            switch (dir) {
                .up => {
                    rows /= 2;
                    cur.y_loc += rows;
                    cur.rows = (cur.rows + 1) / 2;
                },
                .down => {
                    rows /= 2;
                    cur.rows = (cur.rows + 1) / 2;
                    y_loc = cur.y_loc + cur.rows;
                },
                .left => {
                    cols /= 2;
                    cur.x_loc += cols;
                    cur.cols = (cur.cols + 1) / 2;
                },
                .right => {
                    cols /= 2;
                    cur.cols = (cur.cols + 1) / 2;
                    x_loc = cur.x_loc + cur.cols;
                },
            }
        } else { // create orginal window
            x_loc = 0;
            y_loc = 0;
            const term_sz = self.term.getSize();
            rows = term_sz.rows;
            cols = term_sz.cols;
        }
        self.windows[self.windows_len] = Window.init(self.stdout, self.term, x_loc, y_loc, rows, cols);
        self.windows_len += 1;
        try self.setCurWindow(&self.windows[self.windows_len - 1]);
    }

    pub fn setCurWindow(self: *Self, window: *Window) !void {
        self.cur_window = window;
        const cursor: *Cursor = &window.cursor;
        try self.term.moveCursorTo(window.y_loc + cursor.y_loc, window.x_loc + cursor.x_loc);
    }

    pub fn changeCurWindow(self: *Self, dir: Direction) !void {
        const cur_window = self.cur_window orelse return;
        const cursor: *Cursor = &cur_window.cursor;
        const window: ?*Window = switch (dir) {
            .up => self.getWindowWithCoord( cur_window.x_loc + cursor.x_loc, cur_window.y_loc -% 1),
            .down => self.getWindowWithCoord( cur_window.x_loc + cursor.x_loc, cur_window.y_loc + cur_window.rows),
            .left => self.getWindowWithCoord( cur_window.x_loc -% 1, cur_window.y_loc + cursor.x_loc),
            .right => self.getWindowWithCoord( cur_window.x_loc + cur_window.cols, cur_window.y_loc + cursor.y_loc),
        };
        try self.setCurWindow(window orelse return);
    }
};
