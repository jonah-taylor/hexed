const std = @import("std");
const Cursor = @import("cursor").Cursor;
const Terminal = @import("terminal").Terminal;

// const Display = union(enum) {
//     text_win: TextWin,
//     file_win: FileWin,
//     buf_win: BufWin,
// };

pub const Tile = struct {
    const Self = @This();

    stdout: *std.Io.Writer,
    term: *Terminal,
    cursor: Cursor,
    x1: u16,
    y1: u16,
    x2: u16,
    y2: u16,

    pub fn init(stdout: *std.Io.Writer, term: *Terminal, x1: u16, y1: u16, x2: u16, y2: u16) Self {
        return .{
            .stdout = stdout,
            .term = term,
            .cursor = Cursor.init(stdout),
            .x1 = x1,
            .y1 = y1,
            .x2 = x2,
            .y2 = y2,
        };
    }

    pub fn hasCoord(self: *Self, x: u16, y: u16) bool {
        return x >= self.x1 and x <= self.x2 and y >= self.y1 and y <= self.y2;
    }

    pub fn drawBorder(self: *Self, idx: usize) !void {
        const prop_x1 = self.term.fixedFromPercX(self.x1);
        const prop_y1 = self.term.fixedFromPercY(self.y1);
        const prop_x2 = self.term.fixedFromPercX(self.x2);
        const prop_y2 = self.term.fixedFromPercY(self.y2);

        try self.term.placeCharAt(prop_y1 + 2, prop_x1 + 2, '0' + @as(u8, @truncate(idx)));

        for (0..prop_x2 - prop_x1) |x| {
            try self.term.placeCharAt(prop_y1, prop_x1 + @as(u16, @intCast(x)), '+');
            try self.term.placeCharAt(prop_y2, prop_x1 + @as(u16, @intCast(x)), '+');
        }
        for (0..prop_y2 - prop_y1) |y| {
            try self.term.placeCharAt(prop_y1 + @as(u16, @intCast(y)), prop_x1, '+');
            try self.term.placeCharAt(prop_y1 + @as(u16, @intCast(y)), prop_x2, '+');
        }
    }
};
