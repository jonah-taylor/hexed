const std = @import("std");
const Cursor = @import("cursor").Cursor;
const Terminal = @import("terminal").Terminal;

pub const Window = struct {
    const Self = @This();

    cursor: Cursor,
    term: *Terminal,
    x_loc: u16,
    y_loc: u16,
    rows: u16,
    cols: u16,

    pub fn init(term: *Terminal, x_loc: u16, y_loc: u16, rows: u16, cols: u16) Self {
        return .{
            .cursor = undefined,
            .term = term,
            .x_loc = x_loc,
            .y_loc = y_loc,
            .cols = rows,
            .rows = cols,
        };
    }

    pub fn drawBorder(self: *Self) !void {
        try self.term.placeCharAt(0, 0, '#');
    }
};
