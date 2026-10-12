const std = @import("std");
const term = @import("./terminal.zig");

const Cursor = @import("./cursor.zig").Cursor;
const Direction = @import("./geometry.zig").Direction;
const Rectangle = @import("./geometry.zig").Rectangle;

const tile_ops = @import("./tiles/tile.zig");
const Tile = tile_ops.Tile;

const tiler_ops = @import("./tiler.zig");
const Tiler = tiler_ops.Tiler;

pub const App = struct {
    const Self = @This();

    pub const State = enum {
        type,
        edit,
        resize,
    };

    io: *std.Io,
    alloc: std.mem.Allocator,
    state: State,
    stdout: *std.Io.Writer,
    tiler: Tiler,

    pub fn init(io: *std.Io, stdout: *std.Io.Writer, alloc: std.mem.Allocator) Self {
        return .{
            .io = io,
            .alloc = alloc,
            .state = .edit,
            .stdout = stdout,
            .tiler = Tiler.init(alloc),
        };
    }
};

pub fn runApp(app: *App) !void {

    // START OF STUB

    const file = try std.Io.Dir.cwd().openFile(app.io.*, "build.zig", .{});
    defer file.close(app.io.*);

    const stat = try file.stat(app.io.*);
    const contents = try app.alloc.alloc(u8, stat.size);
    defer app.alloc.free(contents);

    var read_buffer: [4096]u8 = undefined;
    var reader = file.reader(app.io.*, &read_buffer);

    try reader.interface.readSliceAll(contents);

    // END OF STUB

    try term.setCursorBlock(app.stdout);

    try term.clear(app.stdout);
    var term_sz = term.getSize();
    var prev_term_sz = term_sz;
    var curr_tile = tiler_ops.getTile(&app.tiler);

    try drawTiles(app);
    app.stdout.flush() catch {};

    while (true) {

        if (!try processKeybinds(app, contents)) break;

        curr_tile = tiler_ops.getTile(&app.tiler);

        if (app.state == .resize)
            try term.clear(app.stdout);

        // window resizing
        term_sz = term.getSize();
        if (term_sz.cols != prev_term_sz.cols or term_sz.rows != prev_term_sz.rows) {
            try term.clear(app.stdout);
        }

        prev_term_sz = term_sz;

        try drawTiles(app);

        if (app.state == .resize)
            try term.colorReset(app.stdout);

        try tile_ops.updateCursor(tiler_ops.getTile(&app.tiler), app.stdout);
        app.stdout.flush() catch {};
    }
}

fn drawTiles(app: *App) !void {
    try term.clear(app.stdout);
    try term.saveCursorPos(app.stdout);
    for (0..app.tiler.tiles_len) |i| {
        // try term.drawRectangle(app.stdout, &app.tiler.tiles[i], &app.state);
        try term.drawTile(app.stdout, &app.tiler.tiles[i], &app.state);
    }
    try term.loadCursorPos(app.stdout);
}

fn processKeybinds(app: *App, contents: []u8) !bool {
    var tlr = &app.tiler;
    var key: u8 = '.';
    const name = "build.zig";
    const curr_tile = tiler_ops.getTile(tlr);
    key = try term.getch();
    switch (key) {
    'D' => {
        tlr.tile_idx = tiler_ops.rmTile(tlr) catch {
            try term.clear(app.stdout);
            try tile_ops.updateCursor(tiler_ops.getTile(&app.tiler), app.stdout);
            try app.stdout.flush();
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
        try switch (app.state) {
        .edit => tile_ops.moveCursorLeft(curr_tile),
        .resize => tiler_ops.resizeTile(tlr, Direction.left, tlr.tile_idx, true),
        else => {},
        };
    },
    'H' => {
        tlr.tile_idx = tiler_ops.tileIdxFromCursorDir(tlr, Direction.left)
            orelse return true;
    },
    'j' => {
        try switch (app.state) {
        .edit => tile_ops.moveCursorDown(curr_tile),
        .resize => tiler_ops.resizeTile(tlr, Direction.down, tlr.tile_idx, true),
        else => {},
        };
    },
    'J' => {
        tlr.tile_idx = tiler_ops.tileIdxFromCursorDir(tlr, Direction.down)
            orelse return true;
    },
    'k' => {
        try switch (app.state) {
        .edit => tile_ops.moveCursorUp(curr_tile),
        .resize => tiler_ops.resizeTile(tlr, Direction.up, tlr.tile_idx, true),
        else => {},
        };
    },
    'K' => {
        tlr.tile_idx = tiler_ops.tileIdxFromCursorDir(tlr, Direction.up)
            orelse return true;
    },
    'l' => {
        try switch (app.state) {
        .edit => tile_ops.moveCursorRight(curr_tile),
        .resize => tiler_ops.resizeTile(tlr, Direction.right, tlr.tile_idx, true),
        else => {},
        };
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
            app.state = .edit;
        } else {
            app.state = .resize;
        }
    },
    't' => {
        key = try term.getch();
        switch (key) {
        'h' => tiler_ops.newTile(tlr, Direction.left, contents, name[0..]) catch {},
        'j' => tiler_ops.newTile(tlr, Direction.down, contents, name[0..]) catch {},
        'k' => tiler_ops.newTile(tlr, Direction.up, contents, name[0..]) catch {},
        'l' => tiler_ops.newTile(tlr, Direction.right, contents, name[0..]) catch {},
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
    '\t' => {
        if (app.state == .edit) {
            app.state = .type;
            try term.setCursorLine(app.stdout);
        }
        else {
            app.state = .edit;
            try term.setCursorBlock(app.stdout);
        }
    },
    else => {},
    }
    return true;
}

