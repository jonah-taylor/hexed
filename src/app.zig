const std = @import("std");
const term = @import("./terminal.zig");

const Cursor = @import("./cursor.zig").Cursor;
const Direction = @import("./geometry.zig").Direction;
const Rectangle = @import("./geometry.zig").Rectangle;
const Tile = @import("./tiles/tile.zig").Tile;

const tiler_ops = @import("./tiler.zig");
const Tiler = tiler_ops.Tiler;

pub const App = struct {
    const Self = @This();

    const State = enum {
        normal,
        resize,
    };

    alloc: std.mem.Allocator,
    state: State,
    stdout: *std.Io.Writer,
    tiler: Tiler,

    pub fn init(stdout: *std.Io.Writer, alloc: std.mem.Allocator) Self {
        return .{
            .alloc = alloc,
            .state = .normal,
            .stdout = stdout,
            .tiler = Tiler.init(),
        };
    }
};

pub fn runApp(app: *App) !void {

    try term.clear(app.stdout);
    var term_sz = term.getSize();
    var prev_term_sz = term_sz;
    var curr_tile = tiler_ops.getTile(&app.tiler);

    try drawTiles(app);
    app.stdout.flush() catch {};

    while (true) {

        if (!try processKeybinds(app)) break;

        curr_tile = tiler_ops.getTile(&app.tiler);

        if (app.state == .resize) {
            try term.clear(app.stdout);
            try term.setRed(app.stdout);
        }

        term_sz = term.getSize();
        if (term_sz.cols != prev_term_sz.cols or term_sz.rows != prev_term_sz.rows) {
            try term.clear(app.stdout);
            const tile = &app.tiler.tiles[app.tiler.tile_idx];
            const cursor = &tile.cursor;
            try term.moveCursorTo(
                app.stdout,
                term.fixedFromPercY(tile.pos.y1) + cursor.y,
                term.fixedFromPercX(tile.pos.x1) + cursor.x
            );
        }

        try term.moveCursorTo(
            app.stdout,
            term.fixedFromPercY(curr_tile.pos.y1) + curr_tile.cursor.y,
            term.fixedFromPercX(curr_tile.pos.x1) + curr_tile.cursor.x
        );

        prev_term_sz = term_sz;

        try drawTiles(app);

        if (app.state == .resize)
            try term.colorReset(app.stdout);

        try updateCursor(app);
        app.stdout.flush() catch {};
    }
}

fn drawTiles(app: *App) !void {
    try term.saveCursorPos(app.stdout);
    for (0..app.tiler.tiles_len) |i| {
        try term.drawRectangle(app.stdout, &app.tiler.tiles[i].pos, i);
    }
    try term.loadCursorPos(app.stdout);
}

fn updateCursor(app: *App) !void {
    const tile = tiler_ops.getTile(&app.tiler);
    const cursor: *Cursor = &tile.cursor;
    const new_cur_x = term.fixedFromPercY(tile.pos.y1) + cursor.y;
    const new_cur_y = term.fixedFromPercX(tile.pos.x1) + cursor.x;
    try term.moveCursorTo(app.stdout, new_cur_x, new_cur_y);
}


fn processKeybinds(app: *App) !bool {
    var tlr = &app.tiler;
    var key: u8 = '.';
    const curr_tile = tiler_ops.getTile(tlr);
    key = try term.getch();
    switch (key) {
    'D' => {
        tlr.tile_idx = tiler_ops.rmTile(tlr) catch {
            try term.clear(app.stdout);
            try term.moveCursorTo(app.stdout, 0, 0);
            app.stdout.flush() catch {};
            return false;
        };
        try term.clear(app.stdout);
    },
    'c' => {
        key = try term.getch();

        switch (key) {
        'k' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.up, true) catch {};
            try term.clear(app.stdout);
        },
        'j' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.down, true) catch {};
            try term.clear(app.stdout);
        },
        'h' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.left, true) catch {};
            try term.clear(app.stdout);
        },
        'l' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.right, true) catch {};
            try term.clear(app.stdout);
        },
        else => {},
        }

    },
    'C' => {
        key = try term.getch();
        switch (key) {
        'k' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.up, false) catch {};
            try term.clear(app.stdout);
        },
        'j' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.down, false) catch {};
            try term.clear(app.stdout);
        },
        'h' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.left, false) catch {};
            try term.clear(app.stdout);
        },
        'l' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.right, false) catch {};
            try term.clear(app.stdout);
        },
        else => {},
        }
    },
    'h' => {
        switch (app.state) {
        .normal => curr_tile.cursor.x -= 1,
        .resize => try tiler_ops.resizeTile(tlr, Direction.left, tlr.tile_idx, true),
        }
    },
    'H' => {
        tlr.tile_idx = tiler_ops.tileIdxFromCursorDir(tlr, Direction.left)
            orelse return true;
    },
    'j' => {
        switch (app.state) {
        .normal => curr_tile.cursor.y += 1,
        .resize => try tiler_ops.resizeTile(tlr, Direction.down, tlr.tile_idx, true),
        }
    },
    'J' => {
        tlr.tile_idx = tiler_ops.tileIdxFromCursorDir(tlr, Direction.down)
            orelse return true;
    },
    'k' => {
        switch (app.state) {
        .normal => curr_tile.cursor.y -= 1,
        .resize => try tiler_ops.resizeTile(tlr, Direction.up, tlr.tile_idx, true),
        }
    },
    'K' => {
        tlr.tile_idx = tiler_ops.tileIdxFromCursorDir(tlr, Direction.up)
            orelse return true;
    },
    'l' => {
        switch (app.state) {
        .normal => curr_tile.cursor.x += 1,
        .resize => try tiler_ops.resizeTile(tlr, Direction.right, tlr.tile_idx, true),
        }
    },
    'L' => {
        tlr.tile_idx = tiler_ops.tileIdxFromCursorDir(tlr, Direction.right)
            orelse return true;
    },
    'q' => {
        try term.clear(app.stdout);
        try term.moveCursorTo(app.stdout, 0, 0);
        app.stdout.flush() catch {};
        return false;
    },
    'R' => {
        if (app.state == .resize) {
            app.state = .normal;
        } else {
            app.state = .resize;
        }
    },
    't' => {
        key = try term.getch();
        switch (key) {
        'h' => tiler_ops.newTile(tlr, Direction.left) catch {},
        'j' => tiler_ops.newTile(tlr, Direction.down) catch {},
        'k' => tiler_ops.newTile(tlr, Direction.up) catch {},
        'l' => tiler_ops.newTile(tlr, Direction.right) catch {},
        's' => {
            key = try term.getch();
            switch (key) {
            'k' => tiler_ops.swapTileInDir(tlr, Direction.up) catch {},
            'j' => tiler_ops.swapTileInDir(tlr, Direction.down) catch {},
            'h' => tiler_ops.swapTileInDir(tlr, Direction.left) catch {},
            'l' => tiler_ops.swapTileInDir(tlr, Direction.right) catch {},
            else => {},
            }
        },
        else => {},
        }
    },
    else => {},
    }
    return true;
}

