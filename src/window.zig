const std = @import("std");
const Cursor = @import("cursor").Cursor;
const Terminal = @import("terminal").Terminal;

pub const Window = struct {
    const Self = @This();

    stdout: *std.Io.Writer,
    term: *Terminal,
    cursor: Cursor,
    x_loc: u16,
    y_loc: u16,
    rows: u16,
    cols: u16,

    pub fn init(stdout: *std.Io.Writer, term: *Terminal, x_loc: u16, y_loc: u16, rows: u16, cols: u16) Self {
        return .{
            .stdout = stdout,
            .term = term,
            .cursor = Cursor.init(stdout),
            .x_loc = x_loc,
            .y_loc = y_loc,
            .cols = rows,
            .rows = cols,
        };
    }

    pub fn drawBorder(self: *Self) !void {
        for (0..self.cols) |x| {
            try self.term.placeCharAt(@as(u16, @intCast(x)), 0, '#');
            try self.term.placeCharAt(@as(u16, @intCast(x)), self.rows, '#');
        }
        for (0..self.rows) |y| {
            try self.term.placeCharAt(0, @as(u16, @intCast(y)), '#');
            try self.term.placeCharAt(self.cols, @as(u16, @intCast(y)), '#');
        }
    }

    pub fn getSize(self: *Self) !struct { rows: u16, cols: u16 } {
        return .{ .rows = self.rows, .cols = self.cols };
    }
};
