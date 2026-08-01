const std = @import("std");

pub const Cursor = struct {
    const Self = @This();

    stdout: *std.Io.Writer,
    x_loc: u16,
    y_loc: u16,

    pub fn init(stdout: *std.Io.Writer) Self {
        return .{
            .stdout = stdout,
            .x_loc = 0,
            .y_loc = 0,
        };
    }
};
