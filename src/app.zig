const std = @import("std");
const ArrayList = std.ArrayList;

const term_ops = @import("terminal.zig");
const Buffer = @import("buffer.zig").Buffer;
const Cursor = @import("cursor.zig").Cursor;
const Direction = @import("geometry.zig").Direction;
const frame_ops = @import("frame.zig");
const Frame = frame_ops.Frame;
const Rectangle = @import("geometry.zig").Rectangle;
const tile_ops = @import("tile.zig");
const Tile = tile_ops.Tile;
const tiler_ops = @import("tiler.zig");
const Tiler = tiler_ops.Tiler;

pub const App = struct {
    const Self = @This();

    pub const State = enum {
        type,
        edit,
        resize,
    };

    alloc: std.mem.Allocator,
    bufs: ArrayList(Buffer),
    frame: Frame,
    io: *std.Io,
    init_termios: std.posix.termios,
    raw_termios: std.posix.termios,
    state: State,
    stdout: *std.Io.Writer,
    tiler: Tiler,

    pub fn init(io: *std.Io, init_termios: std.posix.termios, raw_termios: std.posix.termios, stdout: *std.Io.Writer, alloc: std.mem.Allocator) !Self {

        var bufs: ArrayList(Buffer) = .empty;
        try bufs.append(alloc, Buffer.init(alloc, "empty", "\n"));
        return .{
            .alloc = alloc,
            .bufs = bufs,
            .frame = Frame.init(),
            .io = io,
            .init_termios = init_termios,
            .raw_termios = raw_termios,
            .state = .edit,
            .stdout = stdout,
            .tiler = Tiler.init(alloc, &bufs.items[0]),
        };
    }
};

pub fn getFileContent(app: *App, name: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(app.io.*, name, .{});
    defer file.close(app.io.*);

    const stat = try file.stat(app.io.*);
    const contents: []u8 = try app.alloc.alloc(u8, stat.size);

    var read_buffer: [4096]u8 = undefined;
    var reader = file.reader(app.io.*, &read_buffer);

    try reader.interface.readSliceAll(contents);

    return contents;
}

pub fn runApp(app: *App) !void {

    const name = "Makefile";
    const contents = try getFileContent(app, name);
    defer app.alloc.free(contents);
    try app.bufs.append(app.alloc, Buffer.init(app.alloc, name, contents));

    try term_ops.setCursorBlock(app.stdout);

    try term_ops.clear(app.stdout);
    var term_sz = term_ops.getSize();
    var prev_term_sz = term_ops.getSize();
    var curr_tile = tiler_ops.getTile(&app.tiler);

    try drawTilesOnFrame(app);
    try frame_ops.drawFrameOnTerm(&app.frame, app.stdout, term_sz.rows, term_sz.cols);
    app.stdout.flush() catch {};

    var key_pressed: u8 = undefined;
    while (true) {
        key_pressed = try term_ops.getch();
        if (!try processKey(app, key_pressed)) break;

        curr_tile = tiler_ops.getTile(&app.tiler);

        // window resizing
        term_sz = term_ops.getSize();
        if (prev_term_sz.rows != term_sz.rows or prev_term_sz.cols != term_sz.cols) {
            try term_ops.clear(app.stdout);
            app.frame.prev = @splat(@splat(.{ .ch = .{' ', 0, 0, 0} }));
            prev_term_sz = term_sz;
        }

        try drawTilesOnFrame(app);

        if (app.state == .resize)
            try term_ops.colorReset(app.stdout);

        try frame_ops.drawFrameOnTerm(&app.frame, app.stdout, term_sz.rows, term_sz.cols);
        app.frame.curr = @splat(@splat(.{ .ch = .{' ', 0, 0, 0} }));
        try tile_ops.updateCursor(tiler_ops.getTile(&app.tiler), app.stdout);
        app.stdout.flush() catch {};
    }
}

fn drawTilesOnFrame(app: *App) !void {
    try term_ops.saveCursorPos(app.stdout);
    for (0..app.tiler.tiles_len) |i| {
        try tile_ops.drawTileOnFrame(&app.tiler.tiles[i], &app.frame, &app.state);
    }
    try term_ops.loadCursorPos(app.stdout);
}

fn processKey(app: *App, key_pressed: u8) !bool {
    var key = key_pressed;
    var tlr = &app.tiler;
    const curr_tile = tiler_ops.getTile(tlr);
    switch (key) {
    '\t' => {
        if (app.state == .edit) {
            app.state = .type;
            try term_ops.setCursorLine(app.stdout);
        }
        else {
            app.state = .edit;
            try term_ops.setCursorBlock(app.stdout);
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
        key = try term_ops.getch();

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
        else => {
            return try processKey(app, key);
        },
        }

    },
    'C' => {
        key = try term_ops.getch();
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
        else => {
            return try processKey(app, key);
        },
        }
    },
    'd' => {
        key = try term_ops.getch();
        switch (key) {
        'd' => {
            try tile_ops.delLn(curr_tile, curr_tile.cursor.ln);
        },
        'k' => {
            try tile_ops.delLn(curr_tile, curr_tile.cursor.ln - 1);
        },
        'j' => {
            try tile_ops.delLn(curr_tile, curr_tile.cursor.ln + 1);
        },
        'h' => {
            try tile_ops.delLnFront(curr_tile);
        },
        'l' => {
            try tile_ops.delLnBack(curr_tile);
        },
        else => {
            return try processKey(app, key);
        },
        }
    },
    'D' => {
        tlr.tile_idx = tiler_ops.rmTile(tlr) catch {
            try term_ops.clear(app.stdout);
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
        else => {
            return try processKey(app, key);
        },
        };
    },
    'H' => {
        tlr.tile_idx = tiler_ops.tileIdxFromCursorDir(tlr, Direction.left)
            orelse return true;
    },
    'i' => {
        try tile_ops.heavyCursorLeft(curr_tile);
    },
    'I' => {
        for (0..curr_tile.buf.lines.items[curr_tile.cursor.ln - 1].items.len) |_| {
            try tile_ops.moveCursorLeft(curr_tile);
        }
        for (0..curr_tile.buf.lines.items[curr_tile.cursor.ln - 1].items.len) |_| {
            if (curr_tile.buf.lines.items[curr_tile.cursor.ln - 1].items[curr_tile.cursor.ch - 1] != ' ') {
                break;
            }
            try tile_ops.moveCursorRight(curr_tile);
        }
    },
    'j' => {
        try switch (app.state) {
        .edit => tile_ops.moveCursorDown(curr_tile),
        .resize => tiler_ops.resizeTile(tlr, Direction.down, tlr.tile_idx, true),
        else => {
            return try processKey(app, key);
        },
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
        else => {
            return try processKey(app, key);
        },
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
        else => {
            return try processKey(app, key);
        },
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
    'm' => {
        for (0..10) |_| { // heavyCursorDown
            try tile_ops.moveCursorDown(curr_tile);
        }
    },
    'M' => {
        for (0..10) |_| { // heavyCursorUp
            try tile_ops.moveCursorUp(curr_tile);
        }
    },
    'o' => {
        try tile_ops.heavyCursorRight(curr_tile);
    },
    'O' => {
        for (0..curr_tile.buf.lines.items[curr_tile.cursor.ln - 1].items.len) |_| {
            try tile_ops.moveCursorRight(curr_tile);
        }
    },
    'q' => {
        key = try term_ops.getch();
        switch (key) {
        'q' => {
            try term_ops.clear(app.stdout);
            try term_ops.moveCursorTo(app.stdout, 0, 0);
            app.stdout.flush() catch {};
            return false;
        },
        else => {
            return try processKey(app, key);
        },
        }
    },
    'R' => {
        if (app.state == .resize) {
            app.state = .edit;
        } else {
            app.state = .resize;
        }
    },
    's' => {
        key = try term_ops.getch();
        const init_ch = curr_tile.cursor.ch;
        if (curr_tile.cursor.ch - 1 < curr_tile.buf.lines.items[curr_tile.cursor.ln - 1].items.len) {
            _ = curr_tile.buf.lines.items[curr_tile.cursor.ln - 1].orderedRemove(curr_tile.cursor.ch - 1);
        }

        app.state = .type;
        _ = try processKey(app, key);
        app.state = .edit;

        curr_tile.cursor.ch = init_ch;

    },
    'S' => {
        key = try term_ops.getch();
        switch (key) {
        'k' => tiler_ops.swapTileInDir(tlr, Direction.up) catch {},
        'j' => tiler_ops.swapTileInDir(tlr, Direction.down) catch {},
        'h' => tiler_ops.swapTileInDir(tlr, Direction.left) catch {},
        'l' => tiler_ops.swapTileInDir(tlr, Direction.right) catch {},
        else => {
            return try processKey(app, key);
        },
        }
    },
    't' => {
        key = try term_ops.getch();
        switch (key) {
        'h' => tiler_ops.newTile(tlr, Direction.left, &app.bufs.items[1]) catch {},
        'j' => tiler_ops.newTile(tlr, Direction.down, &app.bufs.items[1]) catch {},
        'k' => tiler_ops.newTile(tlr, Direction.up, &app.bufs.items[1]) catch {},
        'l' => tiler_ops.newTile(tlr, Direction.right, &app.bufs.items[1]) catch {},
        else => {
            return try processKey(app, key);
        },
        }
    },
    // 'u' => {
    // undo
    // },
    'x' => {
        if (curr_tile.cursor.ch - 1 < curr_tile.buf.lines.items[curr_tile.cursor.ln - 1].items.len) {
            _ = curr_tile.buf.lines.items[curr_tile.cursor.ln - 1].orderedRemove(curr_tile.cursor.ch - 1);
        }
    },
    '<' => {
        try tile_ops.typeFrontDeTab(curr_tile);
    },
    '>' => {
        try tile_ops.typeFrontTab(curr_tile);
    },
    0x1A => { // ctrl+z
        try term_ops.exitAltScreen(app.stdout);
        app.stdout.flush() catch {};

        try term_ops.setTermios(app.init_termios);
        try std.posix.kill(0, std.posix.SIG.TSTP);
        try term_ops.setTermios(app.raw_termios);

        try term_ops.enterAltScreen(app.stdout);
        app.frame.prev = @splat(@splat(.{ .ch = .{'\t', 0, 0, 0} }));
    },
    else => {},
    }
    return true;
}

