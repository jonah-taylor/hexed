const std = @import("std");

const term_ops = @import("terminal.zig");

const tile_ops = @import("tiles/tile.zig");
const Tile = tile_ops.Tile;

pub const Frame = struct {
    const Self = @This();

    prev: [1000][1000]u8,
    mat: [1000][1000]u8,

    pub fn init() Self {
        return .{
            .prev = @splat(@splat('.')),
            .mat = @splat(@splat(' ')),
        };
    }
};

pub fn drawFrame(frame: *Frame, stdout: *std.Io.Writer, rows: usize, cols: usize) !void {
    for (0..rows) |row| {
        for (0..cols) |col| {
            if (frame.mat[row][col] != frame.prev[row][col]) {
                try term_ops.placeStrAt(stdout, @as(u16, @intCast(row)),
                    @as(u16, @intCast(col)), &[_]u8{frame.mat[row][col]});
            }
        }
    }
    frame.prev = frame.mat;
}
