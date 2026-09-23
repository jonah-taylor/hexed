const std = @import("std");
const ArrayList = std.ArrayList;

const Cursor = @import("../cursor.zig").Cursor;
const Rectangle = @import("../geometry.zig").Rectangle;

// const bufs_tile_ops = @import("bufs_tile.zig");
// const files_tile_ops = @import("files_tile.zig");
// const grep_tile_ops = @import("grep_tile.zig");
// const shell_tile_ops = @import("shell_tile.zig");
// const text_tile_ops = @import("text_tile.zig");

pub const TileType = enum {
    buffers,
    files,
    grep,
    shell,
    text,
};

pub const Tile = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    cursor: Cursor,
    rect: Rectangle,
    type: TileType,
    lines: ArrayList([]u8),
    line: u16,

    pub fn init(rect: Rectangle, alloc: std.mem.Allocator, buf: []u8) Self {
        var lines: ArrayList([]u8) = .empty;
        var start: usize = 0;
        var end: usize = 0;
        while (end < buf.len) : (end += 1) {
            while (buf[end] != '\n') : (end += 1) {}
            lines.append(alloc, buf[start..end]) catch {};
            start = end + 1;
        }

        return .{
            .alloc = alloc,
            .cursor = Cursor.init(),
            .rect = rect,
            .type = TileType.text,
            .lines = lines,
            .line = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.lines.deinit(self.alloc);
    }

};

pub fn hasCoord(tile: *Tile, x: u16, y: u16) bool {
    return x >= tile.rect.x1 and x <= tile.rect.x2 and y >= tile.rect.y1 and y <= tile.rect.y2;
}

// pub fn draw(tile: *Tile) void {
//     switch (tile.type) {
//     .buffers => bufs_tile_ops.draw(tile),
//     .files => files_tile_ops.draw(tile),
//     .grep => grep_tile_ops.draw(tile),
//     .shell => shell_tile_ops.draw(tile),
//     .text => text_tile_ops.draw(tile),
//     }
// }

