const std = @import("std");
const Cursor = @import("cursor").Cursor;
const Terminal = @import("terminal").Terminal;
const Tile = @import("tile").Tile;

pub const Direction = enum(i8) {
    up = 1,
    down = -1,
    left = 2,
    right = -2,
};

pub const Axis = enum(i8) {
    x = 1,
    y = -1,
};

fn roundToNearest8(x: u16) u16 {
    return (x + 4) / 8 * 8;
}

fn LTX(tiles: [256]Tile, w1_idx: usize, w2_idx: usize) bool {
    return tiles[w1_idx].x1 < tiles[w2_idx].x1;
}

fn GTY(tiles: [256]Tile, w1_idx: usize, w2_idx: usize) bool {
    return tiles[w1_idx].y1 > tiles[w2_idx].y1;
}

pub const Tiler = struct {
    const Self = @This();
    const maxTiles = 256;

    const err = error{
        NewTileTooSmall,
    };

    stdout: *std.Io.Writer,
    term: *Terminal,
    tiles: [maxTiles]Tile,
    tiles_len: usize,
    tile_idx: ?usize,

    pub fn init(stdout: *std.Io.Writer, term: *Terminal) Self {
        return Self{
            .stdout = stdout,
            .term = term,
            .tiles = undefined,
            .tiles_len = 0,
            .tile_idx = null,
        };
    }

    pub fn drawTiles(self: *Self) !void {
        try self.term.saveCursorPos();
        for (0..self.tiles_len) |i| {
            try self.tiles[i].drawBorder(i);
        }
        try self.term.loadCursorPos();
    }

    pub fn getTile(self: *Self) ?*Tile {
        return &self.tiles[self.tile_idx orelse return null];
    }

    pub fn tileIdxFromPoint(self: *Self, x1: u16, y1: u16) ?usize {
        for (0..self.tiles_len) |i| {
            if (self.tiles[i].hasCoord(x1, y1)) {
                return i;
            }
        }
        return null;
    }

    pub fn newTile(self: *Self, dir: Direction) !void {
        if (self.tiles_len >= self.tiles.len)
            return;

        var x1: u16 = undefined;
        var y1: u16 = undefined;
        var x2: u16 = undefined;
        var y2: u16 = undefined;

        if (self.tile_idx) |idx| {
            const tile: *Tile = &self.tiles[idx];

            x1 = tile.x1;
            y1 = tile.y1;
            x2 = tile.x2;
            y2 = tile.y2;

            switch (dir) {
                .up, .down => {
                    if ((y2 - y1) / 2 <= 9)
                        return err.NewTileTooSmall;
                },
                .left, .right => {
                    if ((x2 - x1) / 2 <= 9)
                        return err.NewTileTooSmall;
                },
            }

            switch (dir) {
                .up => {
                    y2 = y1 + (y2 - y1) / 2;
                    y2 = roundToNearest8(y2);
                    tile.y1 = y2;
                },
                .down => {
                    y1 = y1 + (y2 - y1) / 2;
                    y1 = roundToNearest8(y1);
                    tile.y2 = y1;
                },
                .left => {
                    x2 = x1 + (x2 - x1) / 2;
                    x2 = roundToNearest8(x2);
                    tile.x1 = x2;
                },
                .right => {
                    x1 = x1 + (x2 - x1) / 2;
                    x1 = roundToNearest8(x1);
                    tile.x2 = x1;
                },
            }
        } else { // define first tiledow
            x1 = 0;
            y1 = 0;
            x2 = 256;
            y2 = 256;
        }

        self.tiles[self.tiles_len] = Tile.init(self.stdout, self.term, x1, y1, x2, y2);

        self.tiles_len += 1;
        try self.setTile(self.tiles_len - 1);
    }

    pub fn setTile(self: *Self, next_idx: ?usize) !void {
        const idx: usize = next_idx orelse return;
        self.tile_idx = idx;
        const tile: *Tile = &self.tiles[idx];

        const cursor: *Cursor = &tile.cursor;
        const new_cur_x = self.term.fixedFromPercY(tile.y1) + cursor.y;
        const new_cur_y = self.term.fixedFromPercX(tile.x1) + cursor.x;
        try self.term.moveCursorTo(new_cur_x, new_cur_y);
    }

    pub fn rmTile(self: *Self) !bool {
        const food_idx: usize = self.tile_idx orelse return false;

        const food: *Tile = &self.tiles[food_idx];

        // neighbors absorbing the awaited empty space
        var consumers: usize = undefined;
        var buf: [self.tiles.len]usize = undefined;
        var dir: Direction = undefined;

        for (std.enums.values(Direction)) |d| {
            dir = d;

            consumers = self.tileIdxsFromDirTile(dir, food_idx, &buf) orelse continue;

            try self.stdout.print("{}", .{consumers});

            break;
        } else return false;

        for (0..consumers) |i| {
            var cons = &self.tiles[buf[i]];
            switch (dir) {
                .up => cons.y2 = food.y2,
                .down => cons.y1 = food.y1,
                .left => cons.x2 = food.x2,
                .right => cons.x1 = food.x1,
            }
        }

        self.tiles[food_idx] = self.tiles[self.tiles_len - 1];
        self.tiles_len -= 1;

        try self.setTile(if (buf[0] == self.tiles_len)
            food_idx
        else
            buf[0]);

        return true;
    }

    fn distributeTilesAcross(self: *Self, axis: Axis, idxs: []usize, ax1: u16, ay1: u16, ax2: u16, ay2: u16) void {
        var iter = switch(axis) {
            .x => ax1,
            .y => ay1,
        };
        const step = switch (axis) {
            .x => (ax2 - ax1) / @as(u16, @intCast(idxs.len)),
            .y => (ay2 - ay1) / @as(u16, @intCast(idxs.len)),
        };

        for (0..idxs.len) |idx| {
            var tile = &self.tiles[idxs[idx]];
            switch (axis) {
                .x => {
                    tile.y1 = ay1;
                    tile.y2 = ay2;
                    tile.x1 = roundToNearest8(iter);
                    tile.x2 = roundToNearest8(iter + step);
                },
                .y => {
                    tile.x1 = ax1;
                    tile.x2 = ax2;
                    tile.y1 = roundToNearest8(iter);
                    tile.y2 = roundToNearest8(iter + step);
                },
            }

            iter += step;
        }
    }

    pub fn rotateInDir(self: *Self, dir: Direction, op_idx: ?usize, clockwise: bool) !bool {

        const tile_idx: usize = op_idx orelse return false;

        var my_idxs: [self.tiles.len]usize = undefined;
        var your_idxs: [self.tiles.len]usize = undefined;

        const idxs_len = self.getAlignedIdxs(dir, tile_idx, &my_idxs, &your_idxs)
            orelse return false;

        var area_x1: u16 = std.math.maxInt(u16);
        var area_y1: u16 = std.math.maxInt(u16);
        var area_x2: u16 = 0;
        var area_y2: u16 = 0;

        for (0..idxs_len.my_idxs_len) |idx| {
            const tile = &self.tiles[my_idxs[idx]];
            if (tile.y1 < area_y1) area_y1 = tile.y1;
            if (tile.y2 > area_y2) area_y2 = tile.y2;
            if (tile.x1 < area_x1) area_x1 = tile.x1;
            if (tile.x2 > area_x2) area_x2 = tile.x2;
        }

        for (0..idxs_len.your_idxs_len) |idx| {
            const tile = &self.tiles[your_idxs[idx]];
            if (tile.y1 < area_y1) area_y1 = tile.y1;
            if (tile.y2 > area_y2) area_y2 = tile.y2;
            if (tile.x1 < area_x1) area_x1 = tile.x1;
            if (tile.x2 > area_x2) area_x2 = tile.x2;
        }

        const mid_x: u16 = roundToNearest8(area_x1 + (area_x2 - area_x1) / 2);
        const mid_y: u16 = roundToNearest8(area_y1 + (area_y2 - area_y1) / 2);

        switch (dir) {
            .up, .down => {
                // check for horizontal space
                if ((area_x2 - area_x1) / 8 < 1 + 1) return false;
                // check my_idxs fit the left/right area
                if ((area_y2 - area_y1) / 8 < idxs_len.my_idxs_len + 1) return false;
                // check your_idxs fit the right/left area
                if ((area_y2 - area_y1) / 8 < idxs_len.your_idxs_len + 1) return false;

                // check for pure alignment
                for (1..idxs_len.my_idxs_len) |idx| {
                    const curr = &self.tiles[my_idxs[idx]];
                    const prev = &self.tiles[my_idxs[idx - 1]];
                    if (curr.y1 != prev.y1 or curr.y2 != prev.y2)
                        return false;
                }
                for (1..idxs_len.your_idxs_len) |idx| {
                    const curr = &self.tiles[your_idxs[idx]];
                    const prev = &self.tiles[your_idxs[idx - 1]];
                    if (curr.y1 != prev.y1 or curr.y2 != prev.y2)
                        return false;
                }

                // sort idxs
                std.mem.sort(usize, my_idxs[0..idxs_len.my_idxs_len], self.tiles, LTX);
                std.mem.sort(usize, your_idxs[0..idxs_len.your_idxs_len], self.tiles, LTX);
            },
            .left, .right => {
                // check for vertical space
                if ((area_y2 - area_y1) / 8 < 1 + 1) return false;
                // check my_idxs fit the top/bottom area
                if ((area_x2 - area_x1) / 8 < idxs_len.my_idxs_len + 1) return false;
                // check your_idxs fit the bottom/top area
                if ((area_x2 - area_x1) / 8 < idxs_len.your_idxs_len + 1) return false;

                // check for pure alignment
                for (1..idxs_len.my_idxs_len) |idx| {
                    const curr = &self.tiles[my_idxs[idx]];
                    const prev = &self.tiles[my_idxs[idx - 1]];
                    if (curr.x1 != prev.x1 or curr.x2 != prev.x2)
                        return false;
                }
                for (1..idxs_len.your_idxs_len) |idx| {
                    const curr = &self.tiles[your_idxs[idx]];
                    const prev = &self.tiles[your_idxs[idx - 1]];
                    if (curr.x1 != prev.x1 or curr.x2 != prev.x2)
                        return false;
                }

                // sort idxs
                std.mem.sort(usize, my_idxs[0..idxs_len.my_idxs_len], self.tiles, GTY);
                std.mem.sort(usize, your_idxs[0..idxs_len.your_idxs_len], self.tiles, GTY);
            },
        }

        switch (dir) {
            .up => {
                if (clockwise) {
                    self.distributeTilesAcross(.y, my_idxs[0..idxs_len.my_idxs_len], area_x1, area_y1, mid_x, area_y2);
                    self.distributeTilesAcross(.y, your_idxs[0..idxs_len.your_idxs_len], mid_x, area_y1, area_x2, area_y2);
                } else {
                    self.distributeTilesAcross(.y, your_idxs[0..idxs_len.your_idxs_len], area_x1, area_y1, mid_x, area_y2);
                    self.distributeTilesAcross(.y, my_idxs[0..idxs_len.my_idxs_len], mid_x, area_y1, area_x2, area_y2);
                }
            },
            .down => {
                if (clockwise) {
                    self.distributeTilesAcross(.y, your_idxs[0..idxs_len.your_idxs_len], area_x1, area_y1, mid_x, area_y2);
                    self.distributeTilesAcross(.y, my_idxs[0..idxs_len.my_idxs_len], mid_x, area_y1, area_x2, area_y2);
                } else {
                    self.distributeTilesAcross(.y, my_idxs[0..idxs_len.my_idxs_len], area_x1, area_y1, mid_x, area_y2);
                    self.distributeTilesAcross(.y, your_idxs[0..idxs_len.your_idxs_len], mid_x, area_y1, area_x2, area_y2);
                }
            },
            .left => {
                if (clockwise) {
                    self.distributeTilesAcross(.x, my_idxs[0..idxs_len.my_idxs_len], area_x1, mid_y, area_x2, area_y2);
                    self.distributeTilesAcross(.x, your_idxs[0..idxs_len.your_idxs_len], area_x1, area_y1, area_x2, mid_y);
                } else {
                    self.distributeTilesAcross(.x, your_idxs[0..idxs_len.your_idxs_len], area_x1, mid_y, area_x2, area_y2);
                    self.distributeTilesAcross(.x, my_idxs[0..idxs_len.my_idxs_len], area_x1, area_y1, area_x2, mid_y);
                }
            },
            .right => {
                if (clockwise) {
                    self.distributeTilesAcross(.x, my_idxs[0..idxs_len.my_idxs_len], area_x1, area_y1, area_x2, mid_y);
                    self.distributeTilesAcross(.x, your_idxs[0..idxs_len.your_idxs_len], area_x1, mid_y, area_x2, area_y2);
                } else {
                    self.distributeTilesAcross(.x, your_idxs[0..idxs_len.your_idxs_len], area_x1, area_y1, area_x2, mid_y);
                    self.distributeTilesAcross(.x, my_idxs[0..idxs_len.my_idxs_len], area_x1, mid_y, area_x2, area_y2);
                }
            },
        }

        const tile = self.getTile() orelse return false;
        const cursor = &tile.cursor;
        try self.term.moveCursorTo(
            self.term.fixedFromPercY(tile.y1) + cursor.y,
            self.term.fixedFromPercX(tile.x1) + cursor.x
        );
        return true;
    }

    pub fn resizeTile(self: *Self, dirp: Direction, op_idx: ?usize, grotileg: bool) !void {
        var dir = dirp;

        const idx: usize = op_idx orelse return;
        const strength_x: u16 = 8;
        const strength_y: u16 = 8;
        const minCols: u16 = strength_x;
        const minRows: u16 = strength_y;

        var my_idxs: [self.tiles.len]usize = undefined;
        var your_idxs: [self.tiles.len]usize = undefined;

        var is_grotileg: bool = grotileg;

        var op_idxs_len = self.getAlignedIdxs(dir, idx, &my_idxs, &your_idxs);

        // if wall then shrink
        if (op_idxs_len == null) {
            is_grotileg = false;
            dir = @enumFromInt(@intFromEnum(dir) * -1);
            op_idxs_len = self.getAlignedIdxs(dir, idx, &my_idxs, &your_idxs);
        }

        if (op_idxs_len) |adj| {
            // check bounds
            if (is_grotileg) {
                for (0..adj.your_idxs_len) |i| {
                    const tile = &self.tiles[your_idxs[i]];
                    switch (dir) {
                        .up, .down => if (tile.y2 - tile.y1 <= minRows) return,
                        .left, .right => if (tile.x2 - tile.x1 <= minCols) return,
                    }
                }
            } else {
                for (0..adj.my_idxs_len) |i| {
                    const tile = &self.tiles[my_idxs[i]];
                    switch (dir) {
                        .up, .down => if (tile.y2 - tile.y1 <= minRows) return,
                        .left, .right => if (tile.x2 - tile.x1 <= minCols) return,
                    }
                }
            }

            for (0..adj.my_idxs_len) |i| {
                var tile = &self.tiles[my_idxs[i]];
                switch (dir) {
                    .up => {
                        if (is_grotileg) {
                            tile.y1 -= strength_y;
                        } else {
                            tile.y1 += strength_y;
                        }
                    },
                    .down => {
                        if (is_grotileg) {
                            tile.y2 += strength_y;
                        } else {
                            tile.y2 -= strength_y;
                        }
                    },
                    .left => {
                        if (is_grotileg) {
                            tile.x1 -= strength_x;
                        } else {
                            tile.x1 += strength_x;
                        }
                    },
                    .right => {
                        if (is_grotileg) {
                            tile.x2 += strength_x;
                        } else {
                            tile.x2 -= strength_x;
                        }
                    },
                }
            }

            for (0..adj.your_idxs_len) |i| {
                var tile = &self.tiles[your_idxs[i]];
                switch (dir) {
                    .up => {
                        if (is_grotileg) {
                            tile.y2 -= strength_y;
                        } else {
                            tile.y2 += strength_y;
                        }
                    },
                    .down => {
                        if (is_grotileg) {
                            tile.y1 += strength_y;
                        } else {
                            tile.y1 -= strength_y;
                        }
                    },
                    .left => {
                        if (is_grotileg) {
                            tile.x2 -= strength_x;
                        } else {
                            tile.x2 += strength_x;
                        }
                    },
                    .right => {
                        if (is_grotileg) {
                            tile.x1 += strength_x;
                        } else {
                            tile.x1 -= strength_x;
                        }
                    },
                }
            }
        }

        const tile = self.getTile() orelse return;
        const cursor = &tile.cursor;
        try self.term.moveCursorTo(
            self.term.fixedFromPercY(tile.y1) + cursor.y,
            self.term.fixedFromPercX(tile.x1) + cursor.x
        );
    }

    pub fn swapTileInDir(self: *Self, dir: Direction) !void {
        const curr_tile = self.getTile() orelse return;

        const cursor = &curr_tile.cursor;
        const prop_cur_x = self.term.percFromFixedX(cursor.x);
        const prop_cur_y = self.term.percFromFixedY(cursor.y);

        const other_tile_idx: usize = self.tileIdxFromDirPoint(dir,
            curr_tile.x1 + 1 + prop_cur_x,
            curr_tile.y1 + 1 + prop_cur_y
        ) orelse return;

        const other_tile: *Tile = &self.tiles[other_tile_idx];
        std.mem.swap(u16, &curr_tile.x1, &other_tile.x1);
        std.mem.swap(u16, &curr_tile.y1, &other_tile.y1);
        std.mem.swap(u16, &curr_tile.x2, &other_tile.x2);
        std.mem.swap(u16, &curr_tile.y2, &other_tile.y2);

        try self.setTile(other_tile_idx);
    }

    pub fn setTileFromDir(self: *Self, dir: Direction) !void {
        const tile = self.getTile() orelse return;

        const cursor: *Cursor = &tile.cursor;
        const prop_cur_x = self.term.percFromFixedX(cursor.x);
        const prop_cur_y = self.term.percFromFixedY(cursor.y);

        const tile_idx: usize = self.tileIdxFromDirPoint(dir,
            tile.x1 + 1 + prop_cur_x,
            tile.y1 + 1 + prop_cur_y
        ) orelse return;

        try self.setTile(tile_idx);
    }

    fn tileIdxFromDirPoint(self: *Self, dir: Direction, x: u16, y: u16) ?usize {
        const coord_idx = self.tileIdxFromPoint(x, y) orelse return null;

        const tile: *Tile = &self.tiles[coord_idx];
        return switch (dir) {
            .up => return self.tileIdxFromPoint(x, tile.y1 -% 1),
            .down => self.tileIdxFromPoint(x, tile.y2 + 1),
            .left => self.tileIdxFromPoint(tile.x1 -% 1, y),
            .right => self.tileIdxFromPoint(tile.x2 + 1, y),
        };
    }

    fn walk(self: *Self,
        dir: Direction,
        my_border: u16,
        your_border: u16,
        my_tile_idx: usize,
        your_tile_idx: usize,
        my_idxs_len: *usize,
        my_idxs: *[self.tiles.len]usize,
        your_idxs_len: *usize,
        your_idxs: *[self.tiles.len]usize,
        isEqual: *const fn (*Tile, *Tile) bool,
        getShorter: *const fn (*Tile, *Tile) *Tile
    ) void {

        var cur_my_idx: usize = my_tile_idx;
        var cur_your_idx: usize = your_tile_idx;
        var next_idx: usize = undefined;
        var shorter: *Tile = undefined;
        var border: u16 = undefined;

        while (!isEqual(&self.tiles[cur_my_idx], &self.tiles[cur_your_idx])) {
            shorter = getShorter(&self.tiles[cur_my_idx], &self.tiles[cur_your_idx]);

            border = if (shorter == &self.tiles[cur_my_idx]) my_border else your_border;

            next_idx = self.tileIdxFromDirPoint(
                dir,
                if (dir == .up or dir == .down) border else shorter.x1 + 1,
                if (dir == .left or dir == .right) border else shorter.y1 + 1
            ) orelse return;

            if (shorter == &self.tiles[cur_my_idx]) {
                my_idxs[my_idxs_len.*] = next_idx;
                my_idxs_len.* += 1;
                cur_my_idx = next_idx;
            } else {
                your_idxs[your_idxs_len.*] = next_idx;
                your_idxs_len.* += 1;
                cur_your_idx = next_idx;
            }
        }
    }

    fn getAlignedIdxs(self: *Self,
        dir: Direction,
        idx: usize,
        my_idxs: *[self.tiles.len]usize,
        your_idxs: *[self.tiles.len]usize
    ) ?struct { my_idxs_len: usize, your_idxs_len: usize } {

        const my_tile_idx: usize = idx;
        const my_tile: *Tile = &self.tiles[my_tile_idx];

        const your_tile_idx: usize = self.tileIdxFromDirPoint(
            dir,
            my_tile.x1 + 1,
            my_tile.y1 + 1
        ) orelse return null;

        const your_tile: *Tile = &self.tiles[your_tile_idx];

        var my_idxs_len: usize = 0;
        var your_idxs_len: usize = 0;

        my_idxs[0] = my_tile_idx;
        my_idxs_len += 1;
        your_idxs[0] = your_tile_idx;
        your_idxs_len += 1;

        const bounds = struct {
            fn equalUp(w1: *Tile, w2: *Tile) bool {
                return w1.y1 == w2.y1;
            }
            fn shorterUp(w1: *Tile, w2: *Tile) *Tile {
                return if (w1.y1 > w2.y1) w1 else w2;
            }
            fn equalDown(w1: *Tile, w2: *Tile) bool {
                return w1.y2 == w2.y2;
            }
            fn shorterDown(w1: *Tile, w2: *Tile) *Tile {
                return if (w1.y2 < w2.y2) w1 else w2;
            }
            fn equalLeft(w1: *Tile, w2: *Tile) bool {
                return w1.x1 == w2.x1;
            }
            fn shorterLeft(w1: *Tile, w2: *Tile) *Tile {
                return if (w1.x1 > w2.x1) w1 else w2;
            }
            fn equalRight(w1: *Tile, w2: *Tile) bool {
                return w1.x2 == w2.x2;
            }
            fn shorterRight(w1: *Tile, w2: *Tile) *Tile {
                return if (w1.x2 < w2.x2) w1 else w2;
            }
        };

        switch (dir) {
            .right, .left => {
                for ([_]Direction{ .up, .down }) |d| {
                    self.walk(
                        d,
                        if (dir == .right) my_tile.x2 - 1 else my_tile.x1 + 1,
                        if (dir == .right) your_tile.x1 + 1 else your_tile.x2 - 1,
                        my_tile_idx,
                        your_tile_idx,
                        &my_idxs_len,
                        my_idxs,
                        &your_idxs_len,
                        your_idxs,
                        if (d == .up) bounds.equalUp else bounds.equalDown,
                        if (d == .up) bounds.shorterUp else bounds.shorterDown
                    );
                }
            },
            .up, .down => {
                for ([_]Direction{ .left, .right }) |d| {
                    self.walk(d,
                        if (dir == .down) my_tile.y2 - 1 else my_tile.y1 + 1,
                        if (dir == .down) your_tile.y1 + 1 else your_tile.y2 - 1,
                        my_tile_idx,
                        your_tile_idx,
                        &my_idxs_len,
                        my_idxs,
                        &your_idxs_len,
                        your_idxs,
                        if (d == .left) bounds.equalLeft else bounds.equalRight,
                        if (d == .left) bounds.shorterLeft else bounds.shorterRight
                    );
                }
            },
        }

        return .{ .my_idxs_len = my_idxs_len, .your_idxs_len = your_idxs_len };
    }

    pub fn tileIdxsFromDirTile(self: *Self,
        dir: Direction,
        base_idx: usize, out: *[self.tiles.len]usize
    ) ?usize {

        const tile: *Tile = &self.tiles[base_idx];
        var out_len: usize = 0;

        var side_idx: usize = self.tileIdxFromDirPoint(dir, tile.x1 + 1, tile.y1 + 1) orelse return null;

        out[out_len] = side_idx;
        var side_tile: *Tile = &self.tiles[out[out_len]];
        out_len += 1;

        sideiter: switch (dir) {
            .up, .down => {
                if (side_tile.x1 != tile.x1 or side_tile.x2 > tile.x2)
                    return null;
                if (side_tile.x2 == tile.x2)
                    break :sideiter;

                while (true) {
                    const bounds: u16 = if (dir == .up)
                        side_tile.y2 - 1
                    else
                        side_tile.y1 + 1;

                    side_idx = self.tileIdxFromDirPoint(.right, side_tile.x1 + 1, bounds) orelse break;

                    out[out_len] = side_idx;
                    side_tile = &self.tiles[side_idx];
                    out_len += 1;

                    if (side_tile.x2 == tile.x2)
                        break;
                    if (side_tile.x2 > tile.x2)
                        return null;
                }
            },
            .left, .right => {
                if (side_tile.y1 != tile.y1 or side_tile.y2 > tile.y2)
                    return null;
                if (side_tile.y2 == tile.y2)
                    break :sideiter;

                while (true) {
                    const bounds: u16 = if (dir == .left)
                        side_tile.x2 - 1
                    else
                        side_tile.x1 + 1;

                    side_idx = self.tileIdxFromDirPoint(.down, bounds, side_tile.y1 + 1) orelse break;

                    out[out_len] = side_idx;
                    side_tile = &self.tiles[side_idx];
                    out_len += 1;

                    if (side_tile.y2 == tile.y2)
                        break;
                    if (side_tile.y2 > tile.y2)
                        return null;
                }
            },
        }

        return out_len;
    }
};
