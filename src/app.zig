const std = @import("std");
const Cursor = @import("cursor").Cursor;
const Terminal = @import("terminal").Terminal;
const Tiler = @import("tiler").Tiler;
const Direction = @import("tiler").Direction;
const Tiledow = @import("tiledow").Tiledow;

pub const App = struct {
    const Self = @This();

    const State = enum {
        normal,
        resize,
    };

    alloc: std.mem.Allocator,
    stdout: *std.Io.Writer,
    term: *Terminal,
    tiler: Tiler,
    state: State,

    pub fn init(stdout: *std.Io.Writer, alloc: std.mem.Allocator, term: *Terminal) Self {
        return .{
            .alloc = alloc,
            .stdout = stdout,
            .term = term,
            .tiler = Tiler.init(stdout, term),
            .state = .normal,
        };
    }

    pub fn run(self: *Self) !void {
        try self.term.enableRaw();
        defer self.term.disableRaw();

        self.term.clear();

        try self.tiler.newTile(Direction.up);

        var term_sz = self.term.getSize();
        var prev_term_sz = term_sz;
        var curr_tile = &self.tiler.tiles[self.tiler.tile_idx orelse return];

        try self.tiler.drawTiles();
        self.term.flush();

        var key: u8 = '.';
        mainloop: while (true) {
            curr_tile = &self.tiler.tiles[self.tiler.tile_idx orelse break :mainloop];
            key = try self.term.getch();
            try switch (key) {
                'D' => {
                    _ = try self.tiler.rmTile();
                    self.term.clear();
                },
                'c' => {
                    key = try self.term.getch();
                    switch (key) {
                        'k' => {
                            _ = self.tiler.rotateInDir(Direction.up, self.tiler.tile_idx orelse continue, true) catch {};
                            self.term.clear();
                        },
                        'j' => {
                            _ = self.tiler.rotateInDir(Direction.down, self.tiler.tile_idx orelse continue, true) catch {};
                            self.term.clear();
                        },
                        'h' => {
                            _ = self.tiler.rotateInDir(Direction.left, self.tiler.tile_idx orelse continue, true) catch {};
                            self.term.clear();
                        },
                        'l' => {
                            _ = self.tiler.rotateInDir(Direction.right, self.tiler.tile_idx orelse continue, true) catch {};
                            self.term.clear();
                        },
                        else => {},
                    }
                },
                'C' => {
                    key = try self.term.getch();
                    switch (key) {
                        'k' => {
                            _ = self.tiler.rotateInDir(Direction.up, self.tiler.tile_idx orelse continue, false) catch {};
                            self.term.clear();
                        },
                        'j' => {
                            _ = self.tiler.rotateInDir(Direction.down, self.tiler.tile_idx orelse continue, false) catch {};
                            self.term.clear();
                        },
                        'h' => {
                            _ = self.tiler.rotateInDir(Direction.left, self.tiler.tile_idx orelse continue, false) catch {};
                            self.term.clear();
                        },
                        'l' => {
                            _ = self.tiler.rotateInDir(Direction.right, self.tiler.tile_idx orelse continue, false) catch {};
                            self.term.clear();
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
                'H' => self.tiler.setTileFromDir(Direction.left),
                'j' => {
                    switch (self.state) {
                        .normal => curr_tile.cursor.y += 1,
                        .resize => try self.tiler.resizeTile(Direction.down, self.tiler.tile_idx, true),
                    }
                },
                'J' => self.tiler.setTileFromDir(Direction.down),
                'k' => {
                    switch (self.state) {
                        .normal => curr_tile.cursor.y -= 1,
                        .resize => try self.tiler.resizeTile(Direction.up, self.tiler.tile_idx, true),
                    }
                },
                'K' => self.tiler.setTileFromDir(Direction.up),
                'l' => {
                    switch (self.state) {
                        .normal => curr_tile.cursor.x += 1,
                        .resize => try self.tiler.resizeTile(Direction.right, self.tiler.tile_idx, true),
                    }
                },
                'L' => self.tiler.setTileFromDir(Direction.right),
                'q' => {
                    self.term.clear();
                    try self.term.moveCursorTo(0, 0);
                    self.term.flush();
                    break :mainloop;
                },
                'R' => {
                    if (self.state == .resize) {
                        self.state = .normal;
                    } else {
                        self.state = .resize;
                    }
                },
                'S' => {
                    key = try self.term.getch();
                    switch (key) {
                        'k' => self.tiler.swapTileInDir(Direction.up) catch {},
                        'j' => self.tiler.swapTileInDir(Direction.down) catch {},
                        'h' => self.tiler.swapTileInDir(Direction.left) catch {},
                        'l' => self.tiler.swapTileInDir(Direction.right) catch {},
                        else => {},
                    }
                },
                'T' => {
                    key = try self.term.getch();
                    switch (key) {
                        'h' => self.tiler.newTile(Direction.left) catch {},
                        'j' => self.tiler.newTile(Direction.down) catch {},
                        'k' => self.tiler.newTile(Direction.up) catch {},
                        'l' => self.tiler.newTile(Direction.right) catch {},
                        else => {},
                    }
                },
                else => {},
            };

            curr_tile = &self.tiler.tiles[self.tiler.tile_idx orelse break :mainloop];

            if (self.state == .resize) {
                self.term.clear();
                try self.term.setRed();
            }

            term_sz = self.term.getSize();
            // if (term_sz.cols != prev_term_sz.cols or term_sz.rows != prev_term_sz.rows) {
            //     self.term.clear();
            //     const tile = &self.tiler.tiles[self.tiler.tile_idx orelse return];
            //     const cursor = &tile.cursor;
            //     try self.term.moveCursorTo(self.term.fixedFromPercY(tile.y1) + cursor.y, self.term.fixedFromPercX(tile.x1) + cursor.x);
            // }

            try self.term.moveCursorTo(self.term.fixedFromPercY(curr_tile.y1) + curr_tile.cursor.y, self.term.fixedFromPercX(curr_tile.x1) + curr_tile.cursor.x);
            prev_term_sz = term_sz;

            try self.tiler.drawTiles();

            if (self.state == .resize)
                try self.term.colorReset();

            self.term.flush();
        }
    }
};
