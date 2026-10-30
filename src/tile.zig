const std = @import("std");
const ArrayList = std.ArrayList;

const App = @import("app.zig").App;
const Buffer = @import("buffer.zig").Buffer;
const Cursor = @import("cursor.zig").Cursor;
const Frame = @import("frame.zig").Frame;
const Rectangle = @import("geometry.zig").Rectangle;
const term_ops = @import("terminal.zig");

pub const TileType = enum {
    buffers,
    files,
    grep,
    shell,
    text,
};

pub const Tile = struct {
    const Self = @This();

    buf: *Buffer,
    cursor: Cursor,
    rect: Rectangle,
    type: TileType,

    pub fn init(rect: Rectangle, buf: *Buffer) Self {
        return .{
            .buf = buf,
            .cursor = Cursor.init(),
            .rect = rect,
            .type = TileType.text,
        };
    }
};

pub fn hasCoord(tile: *Tile, x: u16, y: u16) bool {
    return x >= tile.rect.x1 and x <= tile.rect.x2 and y >= tile.rect.y1 and y <= tile.rect.y2;
}

fn drawLineOnFrame(tile: *Tile, frame: *Frame, state: *App.State, y_c: u16, ln_i: usize) !bool {

    const lines: []ArrayList(u8) = tile.buf.lines.items;

    var digits: u16 = 0;
    var num = lines.len;
    while (num > 0) : (num /= 10) {
        digits += 1;
    }
    const num_padding: u16 = digits;

    const fixed_x1 = term_ops.fixedFromPercX(tile.rect.x1);
    const fixed_y1 = term_ops.fixedFromPercY(tile.rect.y1);
    const fixed_x2 = term_ops.fixedFromPercX(tile.rect.x2) - 2;
    const fixed_y2 = term_ops.fixedFromPercY(tile.rect.y2) - 1;

    num = @abs(@as(i32, @intCast(ln_i)) - @as(i32, @intCast(tile.cursor.ln - 1)));

    var y: u16 = y_c;
    var x: u16 = num_padding;

    // handle cursor line number
    if (num == 0) {
        num = @as(u16, @intCast(ln_i)) + 1;
        digits = 0;
        while (num > 0) : (num /= 10) {
            digits += 1;
        }
        x = digits;
        num = @as(u16, @intCast(ln_i)) + 1;
    }

    if (y >= 0 and y <= fixed_y2 - fixed_y1) {
        // handle other line numbers
        while (num > 0) : (num /= 10) {
            x -= 1;
            const ch: u8 = '0' + @as(u8, @intCast(num % 10));

            frame.curr[@as(usize, fixed_y1) + y][@as(usize, fixed_x1) + x] = .{ .ch = .{ ch, 0, 0, 0 } };
            if (state.* == .resize)
                frame.curr[@as(usize, fixed_y1) + y][@as(usize, fixed_x1) + x].fg = 31;
        }
    }

    // draw line contents
    x = num_padding + 1;

    for (lines[ln_i].items, 0..lines[ln_i].items.len) |ch, i| {
        if (fixed_x1 + x >= fixed_x2) {
            y +%= 1;
            if (fixed_y1 +% y == fixed_y2) return false;
            x = num_padding + 1;
        }

        if (y >= 0 and y <= fixed_y2 - fixed_y1) switch (ch) {
        ' ' => {
            if (i + 3 < lines[ln_i].items.len and i % 4 == 0 and std.mem.eql(u8, lines[ln_i].items[i..(i + 4)], "    ")) {
                frame.curr[@as(usize, fixed_y1) + y][@as(usize, fixed_x1) + x] = .{ .ch = .{ 0xE2, 0x94, 0x82, 0 }, .len = 3, .fg = 90 };
            } else {
                frame.curr[@as(usize, fixed_y1) + y][@as(usize, fixed_x1) + x] = .{ .ch = .{ 0xC2, 0xB7, 0, 0 }, .len = 2, .fg = 90 };
            }
        },
        else => frame.curr[@as(usize, fixed_y1) + y][@as(usize, fixed_x1) + x] = .{ .ch = .{ ch, 0, 0, 0 } },
        };
        x += 1;
    }

    if (fixed_x1 + x == fixed_x2) {
        y +%= 1;
        if (fixed_y1 +% y == fixed_y2) return false;
        x = num_padding + 1;
    }

    return true;
}

pub fn drawTileOnFrame(tile: *Tile, frame: *Frame, state: *App.State) !void {

    const lines: []ArrayList(u8) = tile.buf.lines.items;

    // ROUND CURSOR TO A VALID LOCATION
    if (tile.cursor.ln > lines.len) tile.cursor.ln = @as(u16, @intCast(lines.len));
    const cll = lines[tile.cursor.ln - 1].items.len;
    if (tile.cursor.ch > cll) tile.cursor.ch = @as(u16, @intCast(cll + 1));

    var digits: u16 = 0;
    var num = lines.len;
    while (num > 0) : (num /= 10) {
        digits += 1;
    }
    const num_padding: u16 = digits;

    const fixed_x1 = term_ops.fixedFromPercX(tile.rect.x1);
    const fixed_y1 = term_ops.fixedFromPercY(tile.rect.y1);
    const fixed_x2 = term_ops.fixedFromPercX(tile.rect.x2) - 2;
    const fixed_y2 = term_ops.fixedFromPercY(tile.rect.y2) - 1;

    var x: u16 = 0;
    var y: u16 = (fixed_y2 - fixed_y1) / 2;

    // draw lines above the type-line
    for (0..(tile.cursor.ln - 1)) |i| {
        const ln_i = tile.cursor.ln - 2 - i;
        y -%= 1;
        if (fixed_x2 > fixed_x1 + num_padding + 1) {
            y -%= @as(u16, @intCast(tile.buf.lines.items[ln_i].items.len / (fixed_x2 - fixed_x1 - num_padding - 1)));
        } else {
            y -%= @as(u16, @intCast(tile.buf.lines.items[ln_i].items.len));
        }
        if (!try drawLineOnFrame(tile, frame, state, y, ln_i)) break;
    }

    if (y > (fixed_y2 - fixed_y1))
        y = 0;

    // draw padding lines after eof
    for (0..y) |i| {
        // draw ~
        x = num_padding + 1;
        const ch: u8 = '~';
        frame.curr[@as(usize, fixed_y1) + i][@as(usize, fixed_x1)] = .{ .ch = .{ ch, 0, 0, 0 }, .fg = 90, };
    }

    y = (fixed_y2 - fixed_y1) / 2;

    // draw type-line and lower
    for ((tile.cursor.ln - 1)..lines.len) |ln_i| {
        if (fixed_y1 + y == fixed_y2) break;
        if (!try drawLineOnFrame(tile, frame, state, y, ln_i)) {
            y +%= 1;
            if (fixed_x2 > fixed_x1 + num_padding + 1) {
                y +%= @as(u16, @intCast(tile.buf.lines.items[ln_i].items.len / (fixed_x2 - fixed_x1 - num_padding - 1)));
            } else {
                y +%= @as(u16, @intCast(tile.buf.lines.items[ln_i].items.len));
            }
            break;
        }
        y +%= 1;
        if (fixed_x2 > fixed_x1 + num_padding + 1) {
            y +%= @as(u16, @intCast(tile.buf.lines.items[ln_i].items.len / (fixed_x2 - fixed_x1 - num_padding - 1)));
        } else {
            y +%= @as(u16, @intCast(tile.buf.lines.items[ln_i].items.len));
        }
    }

    if (y > (fixed_y2 - fixed_y1))
        y = (fixed_y2 - fixed_y1);

    // draw padding lines after eof
    for (0..(fixed_y2 - (fixed_y1 + y))) |i| {
        // draw ~
        x = num_padding + 1;
        const ch: u8 = '~';
        frame.curr[@as(usize, fixed_y1 + y) + i][@as(usize, fixed_x1)] = .{ .ch = .{ ch, 0, 0, 0 }, .fg = 90 };
    }

    // draw filename
    y = fixed_y2;
    x = fixed_x2 -% @as(u16, @intCast(tile.buf.name.len));
    if (x < fixed_x1 or x > 60000) x = fixed_x1;

    for (tile.buf.name) |ch| {
        if (x >= fixed_x2) break;
        frame.curr[y][x] = .{ .ch = .{ ch, 0, 0, 0 } };
        x += 1;
    }
}

pub fn updateCursor(tile: *Tile, stdout: *std.Io.Writer) !void {

    const lines: []ArrayList(u8) = tile.buf.lines.items;

    // ROUND CURSOR TO A VALID LOCATION
    if (tile.cursor.ln > lines.len) tile.cursor.ln = @as(u16, @intCast(lines.len));
    const cll = lines[tile.cursor.ln - 1].items.len;
    if (tile.cursor.ch > cll) tile.cursor.ch = @as(u16, @intCast(cll + 1));

    var digits: u16 = 0;
    var num = lines.len;
    while (num > 0) : (num /= 10) {
        digits += 1;
    }
    const num_padding: u16 = digits;

    const fixed_x1 = term_ops.fixedFromPercX(tile.rect.x1);
    const fixed_y1 = term_ops.fixedFromPercY(tile.rect.y1);
    const fixed_x2 = term_ops.fixedFromPercX(tile.rect.x2) - 2;
    const fixed_y2 = term_ops.fixedFromPercY(tile.rect.y2) - 1;

    const ln_i = tile.cursor.ln - 1;

    var x: u16 = 0;
    var y: u16 = (fixed_y2 - fixed_y1) / 2;

    num = @as(u16, @intCast(ln_i)) + 1;

    x = num_padding + 1;

    // iterate over contents for internal newlines
    if (lines.len > 0) {
        for (0..lines[ln_i].items.len + 1) |i| {
            if (fixed_x1 + x >= fixed_x2) {
                y +%= 1;
                if (fixed_y1 + y == fixed_y2) return;
                x = num_padding + 1;
            }
            if (i == tile.cursor.ch - 1) break;

            x += 1;
        }
    }

    tile.cursor.x = x;
    tile.cursor.y = y;

    try term_ops.moveCursorTo(stdout, fixed_y1 + y, fixed_x1 + x);
}

pub fn moveCursorUp(tile: *Tile) !void {
    const lines: []ArrayList(u8) = tile.buf.lines.items;

    if (lines.len == 0) return;

    if (tile.cursor.ln > 1)
        tile.cursor.ln -= 1;

    const new_ln_len: u16 = @as(u16, @intCast(lines[tile.cursor.ln - 1].items.len));

    tile.cursor.ch = tile.cursor.ideal_ch;

    if (tile.cursor.ch > new_ln_len)
        tile.cursor.ch = new_ln_len + 1;
    if (tile.cursor.ch == 0) // if there are no chars on a line
        tile.cursor.ch = 1;
}

pub fn moveCursorLeft(tile: *Tile) !void {

    if (tile.cursor.ch > 1)
        tile.cursor.ch -= 1;

    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn moveCursorRight(tile: *Tile) !void {
    const lines: []ArrayList(u8) = tile.buf.lines.items;

    if (lines.len == 0) return;

    if (tile.cursor.ch < lines[tile.cursor.ln - 1].items.len + 1)
        tile.cursor.ch += 1;

    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn moveCursorDown(tile: *Tile) !void {
    const lines: []ArrayList(u8) = tile.buf.lines.items;

    if (lines.len == 0) return;

    if (tile.cursor.ln < lines.len)
        tile.cursor.ln += 1;

    const new_ln_len: u16 = @as(u16, @intCast(lines[tile.cursor.ln - 1].items.len));

    tile.cursor.ch = tile.cursor.ideal_ch;

    if (tile.cursor.ch > new_ln_len)
        tile.cursor.ch = new_ln_len + 1;
    if (tile.cursor.ch == 0) // if there are no chars on a line
        tile.cursor.ch = 1;
}

pub fn typeBackspace(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;

    if (cch == 0) {
        if (cln == 0) return;
        tile.cursor.ln -= 1;
        tile.cursor.ch = @as(u16, @intCast(lines.*[cln - 1].items.len + 1));
        try lines.*[cln - 1].appendSlice(tile.buf.alloc, lines.*[cln].items[0..]);
        _ = tile.buf.lines.orderedRemove(cln);
    } else {
        if (cch > 3 and std.mem.eql(u8, lines.*[cln].items[cch-4..cch], "    ")) { // delete tab
            for (0..4) |i| {
                _ = tile.buf.lines.items[cln].orderedRemove(cch - 1 - i);
                tile.cursor.ch -= 1;
                if ((cch - 1 - i) % 4 == 0) break;
            }
        } else {
            _ = tile.buf.lines.items[cln].orderedRemove(cch - 1);
            tile.cursor.ch -= 1;
        }
    }
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeEnter(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;

    // count spaces in current line
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > 0 and spaces < lines.*[cln].items.len and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}

    // fill second line
    try tile.buf.lines.insert(tile.buf.alloc, cln + 1, .empty);
    for (0..spaces) |_| try lines.*[cln + 1].append(tile.buf.alloc, ' ');
    try lines.*[cln + 1].appendSlice(tile.buf.alloc, lines.*[cln].items[(cch)..]);

    // trim the first line
    lines.*[cln].shrinkRetainingCapacity(lines.*[cln].items.len - (lines.*[cln].items.len - (cch)));

    tile.cursor.ln += 1;
    tile.cursor.ch = spaces + 1;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeFrontDeTab(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
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
    const lines = &tile.buf.lines.items;
    const cln = tile.cursor.ln - 1;
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > spaces and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}
    for (0..(4 - spaces % 4)) |_| try lines.*[cln].insert(tile.buf.alloc, 0, ' ');
    tile.cursor.ch += 4 - spaces % 4;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeTab(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;
    var spaces: u16 = 1;
    while ((cch + spaces) % 4 != 0) : (spaces += 1) {}
    for (0..spaces) |_| try lines.*[cln].insert(tile.buf.alloc, cch, ' ');
    tile.cursor.ch += spaces;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn typeNLUp(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
    const cln = tile.cursor.ln - 1;

    // count spaces in current line
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > 0 and spaces < lines.*[cln].items.len and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}

    try tile.buf.lines.insert(tile.buf.alloc, cln, .empty);
    for (0..spaces) |_| try lines.*[cln].append(tile.buf.alloc, ' ');

    tile.cursor.ch = spaces + 1;
}

pub fn typeNLDown(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
    const cln = tile.cursor.ln - 1;

    // count spaces in current line
    var spaces: u16 = 0;
    while (lines.*[cln].items.len > 0 and spaces < lines.*[cln].items.len and lines.*[cln].items[spaces] == ' ') : (spaces += 1) {}

    try tile.buf.lines.insert(tile.buf.alloc, cln + 1, .empty);
    for (0..spaces) |_| try lines.*[cln + 1].append(tile.buf.alloc, ' ');

    tile.cursor.ch = spaces + 1;
    tile.cursor.ln += 1;
}

pub fn typeChar(tile: *Tile, ch: u8) !void {
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;
    try tile.buf.lines.items[cln].insert(tile.buf.alloc, cch, ch);
    tile.cursor.ch += 1;
    tile.cursor.ideal_ch = tile.cursor.ch;
}

pub fn delLn(tile: *Tile, ln: u16) !void {
    const lines = &tile.buf.lines.items;

    if (ln == 0 or ln > lines.len) return;

    var cln = ln - 1;
    var cch = tile.cursor.ch - 1;

    if (lines.len == 1) {
        lines.*[cln].shrinkRetainingCapacity(0);
    } else {
        _ = tile.buf.lines.orderedRemove(cln);
        if (cln == lines.len or cln >= tile.cursor.ln) {
            cln -= 1;
        }
        if (cch > lines.*[cln].items.len) {
            cch = @as(u16, @intCast(lines.*[cln].items.len));
        }
    }

    tile.cursor.ln = cln + 1;
    tile.cursor.ch = cch + 1;
}

pub fn delLnBack(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;
    lines.*[cln].shrinkRetainingCapacity(lines.*[cln].items.len - (lines.*[cln].items.len - (cch)));
}

pub fn delLnFront(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
    const cln = tile.cursor.ln - 1;
    const cch = tile.cursor.ch - 1;
    try tile.buf.lines.insert(tile.buf.alloc, cln, .empty);
    try lines.*[cln].appendSlice(tile.buf.alloc, lines.*[cln + 1].items[(cch)..]);
    _ = tile.buf.lines.orderedRemove(cln + 1);
}

pub fn heavyCursorLeft(tile: *Tile) !void {
    const lines = &tile.buf.lines.items;
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
    const lines = &tile.buf.lines.items;
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

