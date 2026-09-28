const std = @import("std");

const App = @import("app.zig").App;
const tile_ops = @import("tiles/tile.zig");
const Tile = tile_ops.Tile;

pub fn drawTile(stdout: *std.Io.Writer, tile: *Tile, state: *App.State) !void {
    try tile_ops.draw(tile, stdout, state);
}

pub fn drawRectangle(stdout: *std.Io.Writer, tile: *Tile, state: *App.State) !void {
    const fixed_x1 = fixedFromPercX(tile.rect.x1);
    const fixed_y1 = fixedFromPercY(tile.rect.y1);
    const fixed_x2 = fixedFromPercX(tile.rect.x2);
    const fixed_y2 = fixedFromPercY(tile.rect.y2);

    if (state.* == .resize)
        try setRed(stdout);

    for (0..fixed_x2 - fixed_x1) |x| {
        try placeStrAt(stdout, fixed_y1, fixed_x1 + @as(u16, @intCast(x)), "+");
        try placeStrAt(stdout, fixed_y2, fixed_x1 + @as(u16, @intCast(x)), "+");
    }
    for (0..fixed_y2 - fixed_y1) |y| {
        try placeStrAt(stdout, fixed_y1 + @as(u16, @intCast(y)), fixed_x1, "+");
        try placeStrAt(stdout, fixed_y1 + @as(u16, @intCast(y)), fixed_x2, "+");
    }

    try colorReset(stdout);
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

pub fn setGray(stdout: *std.Io.Writer) !void {
    try stdout.print("\x1b[90m", .{});
}

pub fn colorReset(stdout: *std.Io.Writer) !void {
    try stdout.print("\x1b[0m", .{});
}

pub fn placeStrAt(stdout: *std.Io.Writer, row: u16, col: u16, str: []const u8) !void {
    try stdout.print("\x1b[{d};{d}H{s}", .{ row + 1, col + 1, str });
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
