const std = @import("std");
const term = @import("./terminal.zig");

const Cursor = @import("./cursor.zig").Cursor;
const Direction = @import("./geometry.zig").Direction;
const Rectangle = @import("./geometry.zig").Rectangle;
const Tile = @import("./tiles/tile.zig").Tile;
const Tiler = @import("./tiler.zig").Tiler;

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

    pub fn drawTiles(self: *Self) !void {
        try term.saveCursorPos(self.stdout);
        for (0..self.tiler.tiles_len) |i| {
            try term.drawRectangle(self.stdout, &self.tiler.tiles[i].pos, i);
        }
        try term.loadCursorPos(self.stdout);
    }

    pub fn updateCursor(self: *Self) !void {
        const tile = self.tiler.getTile();
        const cursor: *Cursor = &tile.cursor;
        const new_cur_x = term.fixedFromPercY(tile.pos.y1) + cursor.y;
        const new_cur_y = term.fixedFromPercX(tile.pos.x1) + cursor.x;
        try term.moveCursorTo(self.stdout, new_cur_x, new_cur_y);
    }

    pub fn run(self: *Self) !void {

        try term.clear(self.stdout);

        var term_sz = term.getSize();
        var prev_term_sz = term_sz;

        var curr_tile = self.tiler.getTile();

        try self.drawTiles();
        self.stdout.flush() catch {};

        while (true) {

            if (!try self.processKeyBinds()) break;

            curr_tile = self.tiler.getTile();

            if (self.state == .resize) {
                try term.clear(self.stdout);
                try term.setRed(self.stdout);
            }

            term_sz = term.getSize();
            if (term_sz.cols != prev_term_sz.cols or term_sz.rows != prev_term_sz.rows) {
                try term.clear(self.stdout);
                const tile = &self.tiler.tiles[self.tiler.tile_idx];
                const cursor = &tile.cursor;
                try term.moveCursorTo(self.stdout, term.fixedFromPercY(tile.pos.y1) + cursor.y, term.fixedFromPercX(tile.pos.x1) + cursor.x);
            }

            try term.moveCursorTo(self.stdout, term.fixedFromPercY(curr_tile.pos.y1) + curr_tile.cursor.y, term.fixedFromPercX(curr_tile.pos.x1) + curr_tile.cursor.x);
            prev_term_sz = term_sz;

            try self.drawTiles();

            if (self.state == .resize)
                try term.colorReset(self.stdout);

            try self.updateCursor();
            self.stdout.flush() catch {};
        }
    }

    pub fn processKeyBinds(self: *Self) !bool {
        var key: u8 = '.';
        const curr_tile = self.tiler.getTile();
        key = try term.getch();
        switch (key) {
            'D' => {
                self.tiler.tile_idx = try self.tiler.rmTile();
                try term.clear(self.stdout);
            },
            'c' => {
                key = try term.getch();
                switch (key) {
                    'k' => {
                        _ = self.tiler.rotateInDir(Direction.up, true) catch {};
                        try term.clear(self.stdout);
                    },
                    'j' => {
                        _ = self.tiler.rotateInDir(Direction.down, true) catch {};
                        try term.clear(self.stdout);
                    },
                    'h' => {
                        _ = self.tiler.rotateInDir(Direction.left, true) catch {};
                        try term.clear(self.stdout);
                    },
                    'l' => {
                        _ = self.tiler.rotateInDir(Direction.right, true) catch {};
                        try term.clear(self.stdout);
                    },
                    else => {},
                }
            },
            'C' => {
                key = try term.getch();
                switch (key) {
                    'k' => {
                        _ = self.tiler.rotateInDir(Direction.up, false) catch {};
                        try term.clear(self.stdout);
                    },
                    'j' => {
                        _ = self.tiler.rotateInDir(Direction.down, false) catch {};
                        try term.clear(self.stdout);
                    },
                    'h' => {
                        _ = self.tiler.rotateInDir(Direction.left, false) catch {};
                        try term.clear(self.stdout);
                    },
                    'l' => {
                        _ = self.tiler.rotateInDir(Direction.right, false) catch {};
                        try term.clear(self.stdout);
                    },
                    else => {},
                }
            },
            'h' => {
                switch (self.state) {
                    .normal => curr_tile.cursor.x -= 1,
                    .resize => try self.tiler.resizeTile(Direction.left, self.tiler.tile_idx, true),
                }
            },
            'H' => {
                self.tiler.tile_idx = self.tiler.tileIdxFromCursorDir(Direction.left) orelse return true;
            },
            'j' => {
                switch (self.state) {
                    .normal => curr_tile.cursor.y += 1,
                    .resize => try self.tiler.resizeTile(Direction.down, self.tiler.tile_idx, true),
                }
            },
            'J' => {
                self.tiler.tile_idx = self.tiler.tileIdxFromCursorDir(Direction.down) orelse return true;
            },
            'k' => {
                switch (self.state) {
                    .normal => curr_tile.cursor.y -= 1,
                    .resize => try self.tiler.resizeTile(Direction.up, self.tiler.tile_idx, true),
                }
            },
            'K' => {
                self.tiler.tile_idx = self.tiler.tileIdxFromCursorDir(Direction.up) orelse return true;
            },
            'l' => {
                switch (self.state) {
                    .normal => curr_tile.cursor.x += 1,
                    .resize => try self.tiler.resizeTile(Direction.right, self.tiler.tile_idx, true),
                }
            },
            'L' => {
                self.tiler.tile_idx = self.tiler.tileIdxFromCursorDir(Direction.right) orelse return true;
            },
            'q' => {
                try term.clear(self.stdout);
                try term.moveCursorTo(self.stdout, 0, 0);
                self.stdout.flush() catch {};
                return false;
            },
            'R' => {
                if (self.state == .resize) {
                    self.state = .normal;
                } else {
                    self.state = .resize;
                }
            },
            'S' => {
                key = try term.getch();
                switch (key) {
                    'k' => self.tiler.swapTileInDir(Direction.up) catch {},
                    'j' => self.tiler.swapTileInDir(Direction.down) catch {},
                    'h' => self.tiler.swapTileInDir(Direction.left) catch {},
                    'l' => self.tiler.swapTileInDir(Direction.right) catch {},
                    else => {},
                }
            },
            'T' => {
                key = try term.getch();
                switch (key) {
                    'h' => self.tiler.newTile(Direction.left) catch {},
                    'j' => self.tiler.newTile(Direction.down) catch {},
                    'k' => self.tiler.newTile(Direction.up) catch {},
                    'l' => self.tiler.newTile(Direction.right) catch {},
                    else => {},
                }
            },
            else => {},
        }
        return true;
    }
};
