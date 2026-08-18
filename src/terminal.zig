const std = @import("std");

pub const Terminal = struct {
    const Self = @This();
    const clear_cc = "\x1b[2J";
    const posix = std.posix;

    stdout: *std.Io.Writer,
    init_term: posix.termios,

    pub fn init(stdout: *std.Io.Writer) Self {
        return .{
            .stdout = stdout,
            .init_term = undefined,
        };
    }

    pub fn run(self: *Self, code: []const u8) !void {
        try self.stdout.print("{s}", .{code});
    }

    pub fn clear(self: *Self) void {
        self.run(clear_cc) catch {};
    }

    pub fn moveCursorTo(self: *Self, row: u16, col: u16) !void {
        try self.stdout.print("\x1b[{d};{d}H", .{ row + 1, col + 1 });
    }

    pub fn setRed(self: *Self) !void {
        try self.stdout.print("\x1b[31m", .{});
    }

    pub fn colorReset(self: *Self) !void {
        try self.stdout.print("\x1b[0m", .{});
    }

    pub fn placeCharAt(self: *Self, row: u16, col: u16, char: u8) !void {
        try self.stdout.print("\x1b[{d};{d}H{c}", .{ row + 1, col + 1, char });
    }

    pub fn saveCursorPos(self: *Self) !void {
        try self.run("\x1b[s");
    }

    pub fn loadCursorPos(self: *Self) !void {
        try self.run("\x1b[u");
    }

    pub fn flush(self: *Self) void {
        self.stdout.flush() catch return;
    }

    pub fn disableRaw(self: *Self) void {
        posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, self.init_term) catch {};
    }

    pub fn enableRaw(self: *Self) !void {
        self.init_term = try posix.tcgetattr(posix.STDIN_FILENO);

        var raw_term = self.init_term;
        raw_term.lflag.ECHO = false; // don't echo chars
        raw_term.lflag.ICANON = false; // read input by bytes
        raw_term.lflag.ISIG = false; // disable ctrl z and c
        // raw_term.cc[@intFromEnum(std.posix.V.INTR)] = 0; // disable ctrl c
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

    pub fn getSize(self: *Self) struct { rows: u16, cols: u16 } {
        _ = self;
        var ws: posix.winsize = undefined;
        const err = posix.system.ioctl(posix.STDIN_FILENO, posix.T.IOCGWINSZ, @intFromPtr(&ws));
        if (err != 0) unreachable;
        return .{ .rows = ws.row, .cols = ws.col };
    }

    pub fn fixedFromPercX(self: *Self, x: u16) u16 {
        const dim = self.getSize();
        return x * dim.cols / 256;
    }

    pub fn fixedFromPercY(self: *Self, y: u16) u16 {
        const dim = self.getSize();
        return y * dim.rows / 256;
    }

    pub fn percFromFixedX(self: *Self, x: u16) u16 {
        const dim = self.getSize();
        return x * 256 / dim.cols;
    }

    pub fn percFromFixedY(self: *Self, y: u16) u16 {
        const dim = self.getSize();
        return y * 256 / dim.rows;
    }
};
