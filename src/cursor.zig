const std = @import("std");

pub const Cursor = struct {
    const Self = @This();

    stdout: *std.Io.Writer,
    x: u16,
    y: u16,

    pub fn init(stdout: *std.Io.Writer) Self {
        return .{
            .stdout = stdout,
            .x = 1,
            .y = 1,
        };
    }
};
