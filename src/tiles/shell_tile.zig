const std = @import("std");
const App = @import("../app.zig").App;
const Tile = @import("tile.zig").Tile;
const term_ops = @import("../terminal.zig");

pub fn drawContents(tile: *Tile, stdout: *std.Io.Writer, state: *App.State) !void {

    const lines: [][]u8 = tile.lines.items;

    var digits: u16 = 0;
    var num = lines.len;
    while (num > 0) : (num /= 10) {
        digits += 1;
    }
    const num_padding: u16 = digits;

    const fixed_x1 = term_ops.fixedFromPercX(tile.rect.x1);
    const fixed_y1 = term_ops.fixedFromPercY(tile.rect.y1);
    const fixed_x2 = term_ops.fixedFromPercX(tile.rect.x2) - 1;
    const fixed_y2 = term_ops.fixedFromPercY(tile.rect.y2) - 1;

    var x: u16 = 0;
    var y: u16 = 0;

    outer: for (0..lines.len) |ln_i| {
        if (fixed_y1 + y == fixed_y2) break;

        num = @as(u16, @intCast(ln_i)) + 1;

        // draw line number
        x = num_padding;
        while (num > 0) : (num /= 10) {
            x -= 1;
            const ch: u8 = '0' + @as(u8, @intCast(num % 10));

            if (state.* == .resize)
                try term_ops.setRed(stdout);
            try term_ops.placeStrAt(stdout, fixed_y1 + y, fixed_x1 + x, &[_]u8{ch});
            if (state.* == .resize)
                try term_ops.colorReset(stdout);
        }

        // draw line contents
        x = num_padding + 1;

        for (lines[ln_i]) |ch| {
            if (fixed_x1 + x == fixed_x2) {
                y += 1;
                if (fixed_y1 + y == fixed_y2) break :outer;
                x = num_padding + 1;
            }

            switch (ch) {
            ' ' => {
                try term_ops.setGray(stdout);
                try term_ops.placeStrAt(stdout, fixed_y1 + y, fixed_x1 + x, &[_]u8{0xC2, 0xB7});
                try term_ops.colorReset(stdout);
            },
            else => try term_ops.placeStrAt(stdout, fixed_y1 + y, fixed_x1 + x, &[_]u8{ch}),
            }
            x += 1;
        }

        if (fixed_x1 + x == fixed_x2) {
            y += 1;
            if (fixed_y1 + y == fixed_y2) break :outer;
            x = num_padding + 1;
        }

        y += 1;
    }

    // draw padding lines after eof
    for (0..(fixed_y2 - (fixed_y1 + y))) |i| {
        // draw ~
        x = num_padding + 1;
        const ch: u8 = '~';
        try term_ops.setGray(stdout);
        try term_ops.placeStrAt(stdout, fixed_y1 + y + @as(u16, @intCast(i)), fixed_x1, &[_]u8{ch});
        try term_ops.colorReset(stdout);
    }

    // draw filename
    y = fixed_y2;
    x = fixed_x2 -% @as(u16, @intCast(tile.name.len));
    if (x < fixed_x1 or x > 60000) x = fixed_x1;

    for (tile.name) |ch| {
        if (x >= fixed_x2) break;
        try term_ops.placeStrAt(stdout, y, x, &[_]u8{ch});
        x += 1;
    }
}

pub fn updateCursor(tile: *Tile, stdout: *std.Io.Writer) !void {

    const lines: [][]u8 = tile.lines.items;

    var digits: u16 = 0;
    var num = lines.len;
    while (num > 0) : (num /= 10) {
        digits += 1;
    }
    const num_padding: u16 = digits;

    const fixed_x1 = term_ops.fixedFromPercX(tile.rect.x1);
    const fixed_y1 = term_ops.fixedFromPercY(tile.rect.y1);
    const fixed_x2 = term_ops.fixedFromPercX(tile.rect.x2) - 1;
    const fixed_y2 = term_ops.fixedFromPercY(tile.rect.y2) - 1;

    var x: u16 = 0;
    var y: u16 = 0;

    outer: for (0..lines.len) |ln_i| {
        if (fixed_y1 + y == fixed_y2) break;

        num = @as(u16, @intCast(ln_i)) + 1;

        x = num_padding + 1;

        // iterate over contents for internal newlines

        for (0..lines[ln_i].len + 1) |i| {
            if (fixed_x1 + x == fixed_x2) {
                y += 1;
                if (fixed_y1 + y == fixed_y2) break :outer;
                x = num_padding + 1;
            }
            if (ln_i == tile.cursor.ln - 1 and i == tile.cursor.ch - 1) break :outer;

            x += 1;
        }
        y += 1;
    }

    tile.cursor.x = x;
    tile.cursor.y = y;

    try term_ops.moveCursorTo(stdout, fixed_y1 + y, fixed_x1 + x);
}

pub fn moveCursorUp(tile: *Tile) !void {
    if (tile.cursor.ln > 1)
        tile.cursor.ln -= 1;

    const lines: [][]u8 = tile.lines.items;
    const new_ln_len: u16 = @as(u16, @intCast(lines[tile.cursor.ln - 1].len));

    if (tile.cursor.ch > new_ln_len)
        tile.cursor.ch = new_ln_len + 1;
    if (tile.cursor.ch < 1)
        tile.cursor.ch = 1;
}

pub fn moveCursorDown(tile: *Tile) !void {
    const lines: [][]u8 = tile.lines.items;

    if (tile.cursor.ln < lines.len)
        tile.cursor.ln += 1;

    const new_ln_len: u16 = @as(u16, @intCast(lines[tile.cursor.ln - 1].len));

    if (tile.cursor.ch > new_ln_len)
        tile.cursor.ch = new_ln_len + 1;
    if (tile.cursor.ch < 1)
        tile.cursor.ch = 1;
}

pub fn moveCursorLeft(tile: *Tile) !void {

    if (tile.cursor.ch > 1)
        tile.cursor.ch -= 1;
}

pub fn moveCursorRight(tile: *Tile) !void {

    const lines: [][]u8 = tile.lines.items;

    if (tile.cursor.ch < lines[tile.cursor.ln - 1].len + 1)
        tile.cursor.ch += 1;
}
