const std = @import("std");
const ArrayList = std.ArrayList;

const App = @import("app.zig").App;
const Cursor = @import("cursor.zig").Cursor;
const Frame = @import("frame.zig").Frame;
const Rectangle = @import("geometry.zig").Rectangle;

// const bufs_tile_ops = @import("bufs_tile.zig");
// const files_tile_ops = @import("files_tile.zig");
// const grep_tile_ops = @import("grep_tile.zig");
// const shell_tile_ops = @import("shell_tile.zig");
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

pub fn drawTileOnFrame(tile: *Tile, frame: *Frame, state: *App.State) !void {
    // switch (tile.type) {
    // .buffers => try bufs_tile_ops.drawContents(tile, stdout, state),
    // .files => try files_tile_ops.drawContents(tile, stdout, state),
    // .grep => try grep_tile_ops.drawContents(tile, frame, state),
    // .shell => try shell_tile_ops.drawContents(tile, frame, state),
    // .text => 
    // }
    try text_tile_ops.drawContentsOnFrame(tile, frame, state);
}

pub fn updateCursor(tile: *Tile, stdout: *std.Io.Writer) !void {
    // switch (tile.type) {
    // .buffers => try bufs_tile_ops.updateCursor(tile, stdout),
    // .files => try files_tile_ops.updateCursor(tile, stdout),
    // .grep => try grep_tile_ops.updateCursor(tile, stdout),
    // .shell => try shell_tile_ops.updateCursor(tile, stdout),
    // .text => 
    // }
    try text_tile_ops.updateCursor(tile, stdout);
}

pub fn moveCursorUp(tile: *Tile) !void {
    // switch (tile.type) {
    // .buffers => try bufs_tile_ops.moveCursorUp(tile),
    // .files => try files_tile_ops.moveCursorUp(tile),
    // .grep => try grep_tile_ops.moveCursorUp(tile),
    // .shell => try shell_tile_ops.moveCursorUp(tile),
    // .text => 
    // }
    try text_tile_ops.moveCursorUp(tile);
}

pub fn moveCursorLeft(tile: *Tile) !void {
    // switch (tile.type) {
    // .buffers => try bufs_tile_ops.moveCursorLeft(tile),
    // .files => try files_tile_ops.moveCursorLeft(tile),
    // .grep => try grep_tile_ops.moveCursorLeft(tile),
    // .shell => try shell_tile_ops.moveCursorLeft(tile),
    // .text => try 
    // }
    try text_tile_ops.moveCursorLeft(tile);
}

pub fn moveCursorRight(tile: *Tile) !void {
    // switch (tile.type) {
    // .buffers => try bufs_tile_ops.moveCursorRight(tile),
    // .files => try files_tile_ops.moveCursorRight(tile),
    // .grep => try grep_tile_ops.moveCursorRight(tile),
    // .shell => try shell_tile_ops.moveCursorRight(tile),
    // .text => try 
    // }
    try text_tile_ops.moveCursorRight(tile);
}

pub fn moveCursorDown(tile: *Tile) !void {
    // switch (tile.type) {
    // .buffers => try bufs_tile_ops.moveCursorDown(tile),
    // .files => try files_tile_ops.moveCursorDown(tile),
    // .grep => try grep_tile_ops.moveCursorDown(tile),
    // .shell => try shell_tile_ops.moveCursorDown(tile),
    // .text => 
    // }
    try text_tile_ops.moveCursorDown(tile);
}

pub fn typeBackspace(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;

    if (tile.cursor.ch == 1) {
        if (cln == 0) return;
        tile.cursor.ln -= 1;
        tile.cursor.ch = @as(u16, @intCast(lines.*[cln - 1].items.len + 1));
        try lines.*[cln - 1].appendSlice(tile.alloc, lines.*[cln].items[0..]);
        _ = tile.lines.orderedRemove(cln);
    } else {
        _ = tile.lines.items[cln].orderedRemove(cch - 1);
        tile.cursor.ch -= 1;
    }
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeEnter(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;

    // count spaces in current line
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > 0 and spaces < lines.*[cln].items.len and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}

    // fill second line
    try tile.lines.insert(tile.alloc, cln + 1, .empty);
    for (0..spaces) |_| try lines.*[cln + 1].append(tile.alloc, ' ');
    try lines.*[cln + 1].appendSlice(tile.alloc, lines.*[cln].items[(cch)..]);

    // trim the first line
    lines.*[cln].shrinkRetainingCapacity(lines.*[cln].items.len - (lines.*[cln].items.len - (cch)));

    tile.cursor.ln += 1;
    tile.cursor.ch = spaces + 1;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeFrontDeTab(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > spaces and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}
    spaces = 4 - spaces % 4;
    if (spaces == 4) spaces = 0;
    while (lines.*[cln].items.len != 0 and lines.*[cln].items[0] == ' ' and spaces < 4) : (spaces += 1) {
        _ = lines.*[cln].orderedRemove(0);
    if (tile.cursor.ch > 1)
            tile.cursor.ch -= 1;
    }
}

pub fn typeFrontTab(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > spaces and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}
    for (0..(4 - spaces % 4)) |_| try lines.*[cln].insert(tile.alloc, 0, ' ');
    tile.cursor.ch += 4 - spaces % 4;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeTab(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;
    var spaces: u16 = 1;
    while ((cch + spaces) % 4 != 0) : (spaces += 1) {}
    for (0..spaces) |_| try lines.*[cln].insert(tile.alloc, cch, ' ');
    tile.cursor.ch += spaces;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeNLUp(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;

    // count spaces in current line
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > 0 and spaces < lines.*[cln].items.len and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}

    try tile.lines.insert(tile.alloc, cln, .empty);
    for (0..spaces) |_| try lines.*[cln].append(tile.alloc, ' ');

    tile.cursor.ch = spaces + 1;
}

pub fn typeNLDown(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;

    // count spaces in current line
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > 0 and spaces < lines.*[cln].items.len and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}

    try tile.lines.insert(tile.alloc, cln + 1, .empty);
    for (0..spaces) |_| try lines.*[cln + 1].append(tile.alloc, ' ');

    tile.cursor.ch = spaces + 1;
    tile.cursor.ln += 1;
}

pub fn typeChar(tile: *Tile, ch: u8) !void {
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;
    try tile.lines.items[cln].insert(tile.alloc, cch, ch);
    tile.cursor.ch += 1;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn delLn(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;

    if (lines.len == 1) {
        lines.*[cln].shrinkRetainingCapacity(0);
    } else {
        _ = tile.lines.orderedRemove(cln);
        if (cln == lines.len)
            tile.cursor.ln -= 1;
    }
}

pub fn delLnBack(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;
    lines.*[cln].shrinkRetainingCapacity(lines.*[cln].items.len - (lines.*[cln].items.len - (cch)));
}

pub fn delLnFront(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;
    try tile.lines.insert(tile.alloc, cln, .empty);
    try lines.*[cln].appendSlice(tile.alloc, lines.*[cln + 1].items[(cch)..]);
    _ = tile.lines.orderedRemove(cln + 1);
}

pub fn heavyCursorLeft(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    var cch = tile.cursor.ch - 1;

    if (cch == 0) return;

    if (std.ascii.isAlphanumeric(lines.*[cln].items[cch - 1])
        or lines.*[cln].items[cch - 1] == '_') { // go to start of alphnum

        while (cch > 0

            and (std.ascii.isAlphanumeric(lines.*[cln].items[cch - 1])
                or lines.*[cln].items[cch - 1] == '_')) {
            cch -= 1;
        }
    } else { // go to the first alphnum left of cursor
        while (cch > 0
            and !(std.ascii.isAlphanumeric(lines.*[cln].items[cch - 1])
                or lines.*[cln].items[cch - 1] == '_')) {
            cch -= 1;
        }
    }

    tile.cursor.ch = cch + 1;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn heavyCursorRight(tile: *Tile) !void {
    const lines = &tile.lines.items;
    const cln = tile.cursor.ln - 1;
    var cch = tile.cursor.ch - 1;

    if (lines.len == 0 or cch + 1 > lines.*[cln].items.len) return;

    if (std.ascii.isAlphanumeric(lines.*[cln].items[cch])
        or lines.*[cln].items[cch] == '_') { // go to end of alphnum
        while (cch < lines.*[cln].items.len
            and (std.ascii.isAlphanumeric(lines.*[cln].items[cch])
                or lines.*[cln].items[cch] == '_')) {
            cch += 1;
        }
    } else { // go to first alphnum
        while (cch < lines.*[cln].items.len
            and !(std.ascii.isAlphanumeric(lines.*[cln].items[cch])
                or lines.*[cln].items[cch] == '_')) {
            cch += 1;
        }
    }

    tile.cursor.ch = cch + 1;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

