const std = @import("std");
const ArrayList = std.ArrayList;

const App = @import("app.zig").App;
const Frame = @import("frame.zig").Frame;
const Tile = @import("tile.zig").Tile;
const term_ops = @import("terminal.zig");

fn drawLineOnFrame(tile: *Tile, frame: *Frame, state: *App.State, y_c: u16, ln_i: usize) !bool {

    const lines: []ArrayList(u8) = tile.lines.items;

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

    for (lines[ln_i].items) |ch| {
        if (fixed_x1 + x >= fixed_x2) {
            y +%= 1;
            if (fixed_y1 +% y == fixed_y2) return false;
            x = num_padding + 1;
        }

        switch (ch) {
        ' ' => {
            if (y >= 0 and y <= fixed_y2 - fixed_y1)
                // try term_ops.placeStrAt(stdout, fixed_y1 + y, fixed_x1 + x, &[_]u8){ 0xC2, 0xB7 };
                frame.curr[@as(usize, fixed_y1) + y][@as(usize, fixed_x1) + x] = .{ .ch = .{ 0xC2, 0xB7, 0, 0 }, .len = 2, .fg = 90 };
        },
        else => {
            if (y >= 0 and y <= fixed_y2 - fixed_y1)
                // try term_ops.placeStrAt(stdout, fixed_y1 + y, fixed_x1 + x, &[_]u8{ch});
                frame.curr[@as(usize, fixed_y1) + y][@as(usize, fixed_x1) + x] = .{ .ch = .{ ch, 0, 0, 0 } };

        },
        }
        x += 1;
    }

    if (fixed_x1 + x == fixed_x2) {
        y +%= 1;
        if (fixed_y1 + y == fixed_y2) return false;
        x = num_padding + 1;
    }

    return true;
}

pub fn drawContentsOnFrame(tile: *Tile, frame: *Frame, state: *App.State) !void {

    const lines: []ArrayList(u8) = tile.lines.items;

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
            y -%= @as(u16, @intCast(tile.lines.items[ln_i].items.len / (fixed_x2 - fixed_x1 - num_padding - 1)));
        } else {
            y -%= @as(u16, @intCast(tile.lines.items[ln_i].items.len));
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
        // try term_ops.setGray(stdout);
        // try term_ops.placeStrAt(stdout, fixed_y1 + @as(u16, @intCast(i)), fixed_x1, &[_]u8{ch});
        frame.curr[@as(usize, fixed_y1) + i][@as(usize, fixed_x1)] = .{ .ch = .{ ch, 0, 0, 0 } };
        // try term_ops.colorReset(stdout);
    }

    y = (fixed_y2 - fixed_y1) / 2;

    // draw type-line and lower
    for ((tile.cursor.ln - 1)..lines.len) |ln_i| {
        if (fixed_y1 + y == fixed_y2) break;
        if (!try drawLineOnFrame(tile, frame, state, y, ln_i)) {
            y +%= 1;
            if (fixed_x2 > fixed_x1 + num_padding + 1) {
                y +%= @as(u16, @intCast(tile.lines.items[ln_i].items.len / (fixed_x2 - fixed_x1 - num_padding - 1)));
            } else {
                y +%= @as(u16, @intCast(tile.lines.items[ln_i].items.len));
            }
            break;
        }
        y +%= 1;
        if (fixed_x2 > fixed_x1 + num_padding + 1) {
            y +%= @as(u16, @intCast(tile.lines.items[ln_i].items.len / (fixed_x2 - fixed_x1 - num_padding - 1)));
        } else {
            y +%= @as(u16, @intCast(tile.lines.items[ln_i].items.len));
        }
    }

    if (y > (fixed_y2 - fixed_y1))
        y = (fixed_y2 - fixed_y1);

    // draw padding lines after eof
    for (0..(fixed_y2 - (fixed_y1 + y))) |i| {
        // draw ~
        x = num_padding + 1;
        const ch: u8 = '~';
        // try term_ops.setGray(stdout);
        // try term_ops.placeStrAt(stdout, fixed_y1 + y + @as(u16, @intCast(i)), fixed_x1, &[_]u8{ch});
        frame.curr[@as(usize, fixed_y1 + y) + i][@as(usize, fixed_x1)] = .{ .ch = .{ ch, 0, 0, 0 } };
        // try term_ops.colorReset(stdout);
    }

    // draw filename
    y = fixed_y2;
    x = fixed_x2 -% @as(u16, @intCast(tile.name.len));
    if (x < fixed_x1 or x > 60000) x = fixed_x1;

    for (tile.name) |ch| {
        if (x >= fixed_x2) break;
        frame.curr[y][x] = .{ .ch = .{ ch, 0, 0, 0 } };
        x += 1;
    }
}

pub fn updateCursor(tile: *Tile, stdout: *std.Io.Writer) !void {

    const lines: []ArrayList(u8) = tile.lines.items;

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
    if (tile.cursor.ln > 1)
        tile.cursor.ln -= 1;

    const lines: []ArrayList(u8) = tile.lines.items;
    const new_ln_len: u16 = @as(u16, @intCast(lines[tile.cursor.ln - 1].items.len));

    tile.cursor.ch = tile.cursor.ideal_ch;

    if (tile.cursor.ch > new_ln_len)
        tile.cursor.ch = new_ln_len + 1;
    if (tile.cursor.ch == 0) // if there are no chars on a line
        tile.cursor.ch = 1;
}

pub fn moveCursorDown(tile: *Tile) !void {
    const lines: []ArrayList(u8) = tile.lines.items;

    if (tile.cursor.ln < lines.len)
        tile.cursor.ln += 1;

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

    const lines: []ArrayList(u8) = tile.lines.items;

    if (tile.cursor.ch < lines[tile.cursor.ln - 1].items.len + 1)
        tile.cursor.ch += 1;

    tile.cursor.ideal_ch = tile.cursor.ch;
}

