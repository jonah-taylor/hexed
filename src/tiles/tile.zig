const std = @import("std");
const ArrayList = std.ArrayList;

const App = @import("../app.zig").App;
const Cursor = @import("../cursor.zig").Cursor;
const Rectangle = @import("../geometry.zig").Rectangle;

const bufs_tile_ops = @import("bufs_tile.zig");
const files_tile_ops = @import("files_tile.zig");
const grep_tile_ops = @import("grep_tile.zig");
const shell_tile_ops = @import("shell_tile.zig");
const text_tile_ops = @import("text_tile.zig");

pub const TileType = enum {
    buffers,
    files,
    grep,
    shell,
    text,
};

pub const Tile = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    cursor: Cursor,
    rect: Rectangle,
    type: TileType,
    name: []const u8,
    lines: ArrayList(ArrayList(u8)),
    line: u16,

    pub fn init(rect: Rectangle, alloc: std.mem.Allocator, buf: []u8, name: []const u8) Self {
        var lines: ArrayList(ArrayList(u8)) = .empty;
        var idx: usize = 0;
        var start: usize = 0;
        var end: usize = 0;
        while (end < buf.len) : (idx += 1) {
            lines.append(alloc, .empty) catch {};
            while (buf[end] != '\n') : (end += 1) {}
            for (buf[start..end]) |ch| {
                lines.items[idx].append(alloc, ch) catch {};
            }
            start = end + 1;
            end += 1;
        }

        return .{
            .alloc = alloc,
            .cursor = Cursor.init(),
            .rect = rect,
            .type = TileType.text,
            .name = name,
            .lines = lines,
            .line = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.lines.items) |line| {
            line.deinit(self.alloc);
        }
        self.lines.deinit(self.alloc);
    }
};

pub fn hasCoord(tile: *Tile, x: u16, y: u16) bool {
    return x >= tile.rect.x1 and x <= tile.rect.x2 and y >= tile.rect.y1 and y <= tile.rect.y2;
}

pub fn drawContents(tile: *Tile, stdout: *std.Io.Writer, state: *App.State) !void {
    switch (tile.type) {
    .buffers => try bufs_tile_ops.drawContents(tile, stdout, state),
    .files => try files_tile_ops.drawContents(tile, stdout, state),
    .grep => try grep_tile_ops.drawContents(tile, stdout, state),
    .shell => try shell_tile_ops.drawContents(tile, stdout, state),
    .text => try text_tile_ops.drawContents(tile, stdout, state),
    }
}

pub fn updateCursor(tile: *Tile, stdout: *std.Io.Writer) !void {
    switch (tile.type) {
    .buffers => try bufs_tile_ops.updateCursor(tile, stdout),
    .files => try files_tile_ops.updateCursor(tile, stdout),
    .grep => try grep_tile_ops.updateCursor(tile, stdout),
    .shell => try shell_tile_ops.updateCursor(tile, stdout),
    .text => try text_tile_ops.updateCursor(tile, stdout),
    }
}

pub fn moveCursorUp(tile: *Tile) !void {
    switch (tile.type) {
    .buffers => try bufs_tile_ops.moveCursorUp(tile),
    .files => try files_tile_ops.moveCursorUp(tile),
    .grep => try grep_tile_ops.moveCursorUp(tile),
    .shell => try shell_tile_ops.moveCursorUp(tile),
    .text => try text_tile_ops.moveCursorUp(tile),
    }
}

pub fn moveCursorLeft(tile: *Tile) !void {
    switch (tile.type) {
    .buffers => try bufs_tile_ops.moveCursorLeft(tile),
    .files => try files_tile_ops.moveCursorLeft(tile),
    .grep => try grep_tile_ops.moveCursorLeft(tile),
    .shell => try shell_tile_ops.moveCursorLeft(tile),
    .text => try text_tile_ops.moveCursorLeft(tile),
    }
}

pub fn moveCursorRight(tile: *Tile) !void {
    switch (tile.type) {
    .buffers => try bufs_tile_ops.moveCursorRight(tile),
    .files => try files_tile_ops.moveCursorRight(tile),
    .grep => try grep_tile_ops.moveCursorRight(tile),
    .shell => try shell_tile_ops.moveCursorRight(tile),
    .text => try text_tile_ops.moveCursorRight(tile),
    }
}

pub fn moveCursorDown(tile: *Tile) !void {
    switch (tile.type) {
    .buffers => try bufs_tile_ops.moveCursorDown(tile),
    .files => try files_tile_ops.moveCursorDown(tile),
    .grep => try grep_tile_ops.moveCursorDown(tile),
    .shell => try shell_tile_ops.moveCursorDown(tile),
    .text => try text_tile_ops.moveCursorDown(tile),
    }
}

pub fn typeBackspace(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln;
    if (tile.cursor.ch == 1) {
        if (cln == 1) return;
        tile.cursor.ln -= 1;
        tile.cursor.ch = @as(u16, @intCast(lines.*[cln - 2].items.len + 1));
        try lines.*[cln - 2].appendSlice(tile.alloc, lines.*[cln - 1].items[0..]);
        _ = tile.lines.orderedRemove(cln - 1);
    } else {
        _ = tile.lines.items[tile.cursor.ln - 1].orderedRemove(tile.cursor.ch - 2);
        tile.cursor.ch -= 1;
    }
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeEnter(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln;
    const cch = tile.cursor.ch;
    try tile.lines.insert(tile.alloc, cln, .empty);
    try lines.*[cln].appendSlice(tile.alloc, lines.*[cln - 1].items[(cch - 1)..]);
    lines.*[cln - 1].shrinkRetainingCapacity(lines.*[cln - 1].items.len - (lines.*[cln - 1].items.len - (cch - 1)));
    tile.cursor.ln += 1;
    tile.cursor.ch = 1;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeChar(tile: *Tile, ch: u8) !void {
    try tile.lines.items[tile.cursor.ln - 1].insert(tile.alloc, tile.cursor.ch - 1, ch);
    tile.cursor.ch += 1;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

