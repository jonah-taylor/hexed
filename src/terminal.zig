const std = @import("std");
const Window = @import("window").Window;

pub const Terminal = struct {
    const Self = @This();
    const clear_terminal_cc = "\x1b[2J";
    const posix = std.posix;

    stdout: *std.Io.Writer,
    windows: [10]Window,
    windows_len: usize,
    cur_window: ?*Window,
    init_term: posix.termios,

    pub fn init(writer: *std.Io.Writer) Self {
        return Self{
            .stdout = writer,
            .windows = undefined,
            .windows_len = 0,
            .cur_window = null,
            .init_term = undefined,
        };
    }

    pub fn newWindow(self: *Self, x_loc: u16, y_loc: u16, rows: u16, cols: u16) ?*Window {
        if (self.windows_len < 9) {
            self.windows[self.windows_len] = Window.init(self, x_loc, y_loc, rows, cols);
            self.windows_len += 1;
            return &self.windows[self.windows_len - 1];
        }
        return null;
    }

    pub fn run(self: *Self, code: []const u8) void {
        self.stdout.print("{s}", .{code}) catch unreachable;
    }

    pub fn clearTerminal(self: *Self) void {
        self.run(clear_terminal_cc);
    }

    pub fn moveCursorTo(self: *Self, x_loc: u16, y_loc: u16) !void {
        try self.stdout.print("\x1b[{d};{d}H", .{x_loc, y_loc});
    }

    pub fn placeCharAt(self: *Self, x_loc: u16, y_loc: u16, char: u8) !void {
        try self.stdout.print("\x1b[{d};{d}H{c}", .{x_loc, y_loc, char});
    }

    pub fn flush(self: *Self) void {
        self.stdout.flush() catch unreachable;
    }

    pub fn disableRaw(self: *Self) void {
        posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, self.init_term) catch {};
    }

    pub fn enableRaw(self: *Self) !void {
        self.init_term = try posix.tcgetattr(posix.STDIN_FILENO);

        var raw_term = self.init_term;
        raw_term.lflag.ECHO = false; // don't echo chars
        raw_term.lflag.ICANON = false; // read input by bytes
        raw_term.lflag.ISIG = false; // capture ctrl c
        raw_term.iflag.IXON = false; // disable ctrl s/q

        try posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, raw_term);
    }

    pub fn getch(self: *Self) !u8 {
        _ = self;
        return while (true) {
            var buf: [1]u8 = undefined;
            const n = try posix.read(posix.STDIN_FILENO, &buf);
            if (n != 0) break buf[0];
        };
    }

    pub fn getSize(self: *Self) !struct { rows: u16, cols: u16 } {
        _ = self;
        var ws: posix.winsize = undefined;
        const err = posix.system.ioctl(posix.STDIN_FILENO, posix.T.IOCGWINSZ, @intFromPtr(&ws));
        if (err != 0) return error.IoctlFailed;
        return .{ .rows = ws.row, .cols = ws.col };
    }

};
