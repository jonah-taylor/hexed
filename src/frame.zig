const std = @import("std");

const term_ops = @import("terminal.zig");

const tile_ops = @import("tiles/tile.zig");
const Tile = tile_ops.Tile;

pub const Cell = struct {
    ch: [4]u8 = .{' ', 0, 0, 0},
    len: u8 = 1,
    fg: u8 = 1,
    bg: u8 = 0,
};

pub const Frame = struct {
    const Self = @This();

    prev: [300][300]Cell,
    curr: [300][300]Cell,

    pub fn init() Self {
        return .{
            .prev = @splat(@splat(.{ .ch = .{'.', 0, 0, 0} })),
            .curr = @splat(@splat(.{ .ch = .{' ', 0, 0, 0} })),
        };
    }
};

pub fn drawFrame(frame: *Frame, stdout: *std.Io.Writer, rows: usize, cols: usize) !void {
    try term_ops.hideCursor(stdout);
    for (0..rows) |row| {
        for (0..cols) |col| {
            const curr = frame.curr[row][col];
            const prev = frame.prev[row][col];
            if (!std.mem.eql(u8, &curr.ch, &prev.ch)
                or curr.len != prev.len
                or curr.fg != prev.fg
                or curr.bg != prev.bg) {
                try term_ops.setColors(stdout, curr.fg, curr.bg);
                try term_ops.placeStrAt(stdout, @as(u16, @intCast(row)),
                    @as(u16, @intCast(col)), curr.ch[0..curr.len]);
            }
        }
    }
    frame.prev = frame.curr;
    try term_ops.showCursor(stdout);
}
