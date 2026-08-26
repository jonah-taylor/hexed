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
            // .base = BaseTile.init(pos),
            .cursor = Cursor.init(),
            .pos = pos,
            // .type = .files,
        };
    }

    pub fn hasCoord(self: *Self, x: u16, y: u16) bool {
        return x >= self.pos.x1 and x <= self.pos.x2 and y >= self.pos.y1 and y <= self.pos.y2;
    }
};
