const std = @import("std");
const Rectangle = @import("./geometry.zig").Rectangle;

pub fn drawRectangle(stdout: *std.Io.Writer, rect: *Rectangle, idx: usize) !void {
    const prop_x1 = fixedFromPercX(rect.x1);
    const prop_y1 = fixedFromPercY(rect.y1);
    const prop_x2 = fixedFromPercX(rect.x2);
    const prop_y2 = fixedFromPercY(rect.y2);

    try placeCharAt(stdout, prop_y1 + 2, prop_x1 + 2, '0' + @as(u8, @truncate(idx)));

    for (0..prop_x2 - prop_x1) |x| {
        try placeCharAt(stdout, prop_y1, prop_x1 + @as(u16, @intCast(x)), '+');
        try placeCharAt(stdout, prop_y2, prop_x1 + @as(u16, @intCast(x)), '+');
    }
    for (0..prop_y2 - prop_y1) |y| {
        try placeCharAt(stdout, prop_y1 + @as(u16, @intCast(y)), prop_x1, '+');
        try placeCharAt(stdout, prop_y1 + @as(u16, @intCast(y)), prop_x2, '+');
    }
}

pub fn clear(stdout: *std.Io.Writer) !void {
    try stdout.print("\x1b[2J", .{});
}

pub fn moveCursorTo(stdout: *std.Io.Writer, row: u16, col: u16) !void {
    try stdout.print("\x1b[{d};{d}H", .{ row + 1, col + 1 });
}

pub fn setRed(stdout: *std.Io.Writer) !void {
    try stdout.print("\x1b[31m", .{});
}

pub fn colorReset(stdout: *std.Io.Writer) !void {
    try stdout.print("\x1b[0m", .{});
}

pub fn placeCharAt(stdout: *std.Io.Writer, row: u16, col: u16, char: u8) !void {
    try stdout.print("\x1b[{d};{d}H{c}", .{ row + 1, col + 1, char });
}

pub fn saveCursorPos(stdout: *std.Io.Writer) !void {
    try stdout.print("\x1b[s", .{});
}

pub fn loadCursorPos(stdout: *std.Io.Writer) !void {
    try stdout.print("\x1b[u", .{});
}

pub fn setTermios(termios_cfg: std.posix.termios) void {
    std.posix.tcsetattr(std.posix.STDIN_FILENO, .FLUSH, termios_cfg) catch {};
}

pub fn createRawTermiosFrom(termios: std.posix.termios) std.posix.termios {

    var raw_termios = termios;
    raw_termios.lflag.ECHO = false; // don't echo chars
    raw_termios.lflag.ICANON = false; // read input by bytes
    raw_termios.lflag.ISIG = false; // disable ctrl z and c
    // raw_termios.cc[@intFromEnum(std.posix.V.INTR)] = 0; // disable ctrl c
    raw_termios.iflag.IXON = false; // disable ctrl s/q

    return raw_termios;
}

pub fn getch() !u8 {
    return while (true) {
        var buf: [1]u8 = undefined;
        const n = try std.posix.read(std.posix.STDIN_FILENO, &buf);
        if (n != 0) break buf[0];
    };
}

pub fn getSize() struct { rows: u16, cols: u16 } {
    var ws: std.posix.winsize = undefined;
    const err = std.posix.system.ioctl(std.posix.STDIN_FILENO, std.posix.T.IOCGWINSZ, @intFromPtr(&ws));
    if (err != 0) unreachable;
    return .{ .rows = ws.row, .cols = ws.col };
}

pub fn fixedFromPercX(x: u16) u16 {
    const dim = getSize();
    return x * dim.cols / 256;
}

pub fn fixedFromPercY(y: u16) u16 {
    const dim = getSize();
    return y * dim.rows / 256;
}

pub fn percFromFixedX(x: u16) u16 {
    const dim = getSize();
    return x * 256 / dim.cols;
}

pub fn percFromFixedY(y: u16) u16 {
    const dim = getSize();
    return y * 256 / dim.rows;
}
