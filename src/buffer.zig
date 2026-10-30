const std = @import("std");
const ArrayList = std.ArrayList;

pub const Buffer = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    name: []const u8,
    lines: ArrayList(ArrayList(u8)),

    pub fn init(alloc: std.mem.Allocator, name: []const u8, contents: []const u8) Self {
        var lines: ArrayList(ArrayList(u8)) = .empty;
        var idx: usize = 0;
        var start: usize = 0;
        var end: usize = 0;

        while (end < contents.len) : (idx += 1) {
            lines.append(alloc, .empty) catch {};
            while (contents[end] != '\n') : (end += 1) {}
            for (contents[start..end]) |ch| {
                if (ch == '\t') {
                    lines.items[idx].append(alloc, ' ') catch {};
                    while (lines.items[idx].items.len % 4 != 0) {
                        lines.items[idx].append(alloc, ' ') catch {};
                    }
                } else {
                    lines.items[idx].append(alloc, ch) catch {};
                }
            }
            start = end + 1;
            end += 1;
        }

        return .{
            .alloc = alloc,
            .name = name,
            .lines = lines,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.lines.items) |line| {
            line.deinit(self.alloc);
        }
        self.lines.deinit(self.alloc);
    }
};
