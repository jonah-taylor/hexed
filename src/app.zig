const std = @import("std");
const term = @import("./terminal.zig");

const Cursor = @import("./cursor.zig").Cursor;
const Direction = @import("./geometry.zig").Direction;

const frame_ops = @import("./frame.zig");
const Frame = frame_ops.Frame;

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
    frame: Frame,

    pub fn init(io: *std.Io, stdout: *std.Io.Writer, alloc: std.mem.Allocator) Self {
        return .{
            .io = io,
            .alloc = alloc,
            .state = .edit,
            .stdout = stdout,
            .tiler = Tiler.init(alloc),
            .frame = Frame.init(),
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
    var prev_term_sz = term.getSize();
    var curr_tile = tiler_ops.getTile(&app.tiler);

    try drawTilesOnFrame(app);
    try frame_ops.drawFrame(&app.frame, app.stdout, term_sz.rows, term_sz.cols);
    app.stdout.flush() catch {};

    while (true) {
        if (!try processKeybinds(app, contents)) break;

        curr_tile = tiler_ops.getTile(&app.tiler);

        // window resizing
        term_sz = term.getSize();
        if (prev_term_sz.rows != term_sz.rows or prev_term_sz.cols != term_sz.cols) {
            try term.clear(app.stdout);
            app.frame.prev = @splat(@splat(.{ .ch = .{'.', 0, 0, 0} }));
            prev_term_sz = term_sz;
        }

        try drawTilesOnFrame(app);

        if (app.state == .resize)
            try term.colorReset(app.stdout);

        try frame_ops.drawFrame(&app.frame, app.stdout, term_sz.rows, term_sz.cols);
        app.frame.curr = @splat(@splat(.{ .ch = .{' ', 0, 0, 0} }));
        try tile_ops.updateCursor(tiler_ops.getTile(&app.tiler), app.stdout);
        app.stdout.flush() catch {};
    }
}

fn drawTilesOnFrame(app: *App) !void {
    try term.saveCursorPos(app.stdout);
    for (0..app.tiler.tiles_len) |i| {
        try tile_ops.drawTileOnFrame(&app.tiler.tiles[i], &app.frame, &app.state);
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
    '\t' => {
        if (app.state == .edit) {
            app.state = .type;
            try term.setCursorLine(app.stdout);
        }
        else {
            app.state = .edit;
            try term.setCursorBlock(app.stdout);
        }
        return true;
    },
    '\x08', '\x7f' => try tile_ops.typeBackspace(curr_tile),
    '\r', '\n' => try tile_ops.typeEnter(curr_tile),
    '\x1b' => {
        var seq: [16]u8 = undefined;
        const n = try std.posix.read(0, &seq);
        const s: []const u8 = seq[0..n];

        if (s.len == 2 and seq[0] == '[') {
            switch (seq[1]) {
            'A' => try tile_ops.moveCursorUp(curr_tile),
            'B' => try tile_ops.moveCursorDown(curr_tile),
            'D' => try tile_ops.moveCursorLeft(curr_tile),
            'C' => try tile_ops.moveCursorRight(curr_tile),
            else => {}
            }
        } else if (std.mem.eql(u8, s, "[105;5u")) {
            try tile_ops.typeTab(curr_tile);
        }
    },
    else => {
        if (app.state == .type or key == ' ') {
            if (key >= 32 and key <= 126)
                try tile_ops.typeChar(curr_tile, key);
            return true;
        }
    },
    }

    switch (key) {
    'c' => {
        key = try term.getch();

        switch (key) {
        'k' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.up, true) catch {};
        },
        'j' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.down, true) catch {};
        },
        'h' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.left, true) catch {};
        },
        'l' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.right, true) catch {};
        },
        else => {},
        }

    },
    'C' => {
        key = try term.getch();
        switch (key) {
        'k' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.up, false) catch {};
        },
        'j' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.down, false) catch {};
        },
        'h' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.left, false) catch {};
        },
        'l' => {
            _ = tiler_ops.rotateInDir(tlr, Direction.right, false) catch {};
        },
        else => {},
        }
    },
    'D' => {
        tlr.tile_idx = tiler_ops.rmTile(tlr) catch {
            try term.clear(app.stdout);
            try tile_ops.updateCursor(tiler_ops.getTile(&app.tiler), app.stdout);
            try app.stdout.flush();
            return false;
        };
    },
    // 'g' => {
    // goto
    // },
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
    'n' => {
        try tile_ops.typeNLDown(curr_tile);
    },
    'N' => {
        try tile_ops.typeNLUp(curr_tile);
    },
    'q' => {
        try term.clear(app.stdout);
        try term.moveCursorTo(app.stdout, 0, 0);
        app.stdout.flush() catch {};
        return false;
    },
    // 'r' => {
    // redo
    // },
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
    // 'u' => {
    // undo
    // },
    '<' => {
        try tile_ops.typeFrontDeTab(curr_tile);
    },
    '>' => {
        try tile_ops.typeFrontTab(curr_tile);
    },
    else => {},
    }
    return true;
}

