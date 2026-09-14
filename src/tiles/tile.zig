const std = @import("std");
const Cursor = @import("../cursor.zig").Cursor;
const Rectangle = @import("../geometry.zig").Rectangle;

// pub const TileType = union {
//     buffers,
//     files,
//     grep,
//     shell,
//     text,
// };

pub const Tile = struct {
    const Self = @This();

    cursor: Cursor,
    pos: Rectangle,
    // type: TileType,

    pub fn init(pos: Rectangle) Self {
        return .{
            .cursor = Cursor.init(),
            .pos = pos,
            // .type = .files,
        };
    }

};

pub fn hasCoord(tile: *Tile, x: u16, y: u16) bool {
    return x >= tile.pos.x1 and x <= tile.pos.x2 and y >= tile.pos.y1 and y <= tile.pos.y2;
}

pub fn draw(tile: *Tile) void {
    _ = tile;
    return;
}
