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
            .cols = cols,
            .rows = rows,
        };
    }

    pub fn getRegion(self: *Self) struct { x_loc: u16, y_loc: u16, rows: u16, cols: u16 } {
        return .{
            .x_loc = self.x_loc,
            .y_loc = self.y_loc,
            .rows = self.rows,
            .cols = self.cols,
        };
    }

    pub fn hasCoord(self: *Self, x_loc: u16, y_loc: u16) bool {
        return  self.x_loc <= x_loc and 
                self.x_loc + self.cols - 1 >= x_loc and
                self.y_loc <= y_loc and 
                self.y_loc + self.rows - 1 >= y_loc;
    }

    pub fn drawBorder(self: *Self) !void {
        for (0..self.cols) |col| {
            // try self.term.placeCharAt(self.y_loc, self.x_loc + @as(u16, @intCast(col)), '#');
            try self.term.placeCharAt(self.y_loc + self.rows - 1, self.x_loc + @as(u16, @intCast(col)), '_');
        }
        for (0..self.rows) |row| {
            // try self.term.placeCharAt(self.y_loc + @as(u16, @intCast(row)), self.x_loc, '#');
            try self.term.placeCharAt(self.y_loc + @as(u16, @intCast(row)), self.x_loc + self.cols - 1, '|');
        }
    }
};
