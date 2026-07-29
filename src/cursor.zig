const std = @import("std");

pub const Cursor = struct {
    const Self = @This();

    stdout: *std.Io.Writer,
    x_loc: u32,
    y_loc: u32,

    pub fn init(stdout: *std.Io.Writer) void {
        return .{
            .stdout = stdout,
            .x_loc = 0,
            .y_loc = 0,
        };
    }

    pub fn moveTo(self: *Self, x_loc: u32, y_loc: u32) void {
        self.x_loc = x_loc;
        self.y_loc = y_loc;
    }

};
