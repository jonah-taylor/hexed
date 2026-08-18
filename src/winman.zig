const std = @import("std");
const Cursor = @import("cursor").Cursor;
const Terminal = @import("terminal").Terminal;
const Window = @import("window").Window;

pub const Direction = enum(i8) {
    up = 1,
    down = -1,
    left = 2,
    right = -2,
};

fn roundToNearest8(x: u16) u16 {
    return (x + 4) / 8 * 8;
}

fn LTX(wins: [256]Window, w1_idx: usize, w2_idx: usize) bool {
    return wins[w1_idx].x1 < wins[w2_idx].x1;
}

fn GTY(wins: [256]Window, w1_idx: usize, w2_idx: usize) bool {
    return wins[w1_idx].y1 > wins[w2_idx].y1;
}

pub const WinMan = struct {
    const Self = @This();
    const maxWins = 256;

    const err = error{
        NewWinTooSmall,
    };

    stdout: *std.Io.Writer,
    term: *Terminal,
    wins: [maxWins]Window,
    wins_len: usize,
    win_idx: ?usize,

    pub fn init(stdout: *std.Io.Writer, term: *Terminal) Self {
        return Self{
            .stdout = stdout,
            .term = term,
            .wins = undefined,
            .wins_len = 0,
            .win_idx = null,
        };
    }

    pub fn drawWins(self: *Self) !void {
        try self.term.saveCursorPos();
        for (0..self.wins_len) |i| {
            try self.wins[i].drawBorder(i);
        }
        try self.term.loadCursorPos();
    }

    pub fn winIdxFromPoint(self: *Self, x1: u16, y1: u16) ?usize {
        for (0..self.wins_len) |i| {
            if (self.wins[i].hasCoord(x1, y1)) {
                return i;
            }
        }
        return null;
    }

    pub fn newWin(self: *Self, dir: Direction) !void {
        if (self.wins_len >= self.wins.len)
            return;

        var x1: u16 = undefined;
        var y1: u16 = undefined;
        var x2: u16 = undefined;
        var y2: u16 = undefined;

        if (self.win_idx) |idx| {
            const win: *Window = &self.wins[idx];

            x1 = win.x1;
            y1 = win.y1;
            x2 = win.x2;
            y2 = win.y2;

            switch (dir) {
                .up, .down => {
                    if ((y2 - y1) / 2 <= 9)
                        return err.NewWinTooSmall;
                },
                .left, .right => {
                    if ((x2 - x1) / 2 <= 9)
                        return err.NewWinTooSmall;
                },
            }

            switch (dir) {
                .up => {
                    y2 = y1 + (y2 - y1) / 2;
                    y2 = roundToNearest8(y2);
                    win.y1 = y2;
                },
                .down => {
                    y1 = y1 + (y2 - y1) / 2;
                    y1 = roundToNearest8(y1);
                    win.y2 = y1;
                },
                .left => {
                    x2 = x1 + (x2 - x1) / 2;
                    x2 = roundToNearest8(x2);
                    win.x1 = x2;
                },
                .right => {
                    x1 = x1 + (x2 - x1) / 2;
                    x1 = roundToNearest8(x1);
                    win.x2 = x1;
                },
            }
        } else { // define first window
            x1 = 0;
            y1 = 0;
            x2 = 256;
            y2 = 256;
        }

        self.wins[self.wins_len] = Window.init(self.stdout, self.term, x1, y1, x2, y2);

        self.wins_len += 1;
        try self.setWin(self.wins_len - 1);
    }

    pub fn setWin(self: *Self, next_idx: ?usize) !void {
        const idx: usize = next_idx orelse return;
        self.win_idx = idx;
        const win: *Window = &self.wins[idx];

        const cursor: *Cursor = &win.cursor;
        const new_cur_x = self.term.fixedFromPercY(win.y1) + cursor.y;
        const new_cur_y = self.term.fixedFromPercX(win.x1) + cursor.x;
        try self.term.moveCursorTo(new_cur_x, new_cur_y);
    }

    pub fn rmWin(self: *Self) !bool {
        const food_idx: usize = self.win_idx orelse return false;

        const food: *Window = &self.wins[food_idx];

        // neighbors absorbing the awaited empty space
        var consumers: usize = undefined;
        var buf: [self.wins.len]usize = undefined;
        var dir: Direction = undefined;

        for (std.enums.values(Direction)) |d| {
            dir = d;

            consumers = self.winIdxsFromDirWin(dir, food_idx, &buf) orelse continue;

            try self.stdout.print("{}", .{consumers});

            break;
        } else return false;

        for (0..consumers) |i| {
            var cons = &self.wins[buf[i]];
            switch (dir) {
                .up => cons.y2 = food.y2,
                .down => cons.y1 = food.y1,
                .left => cons.x2 = food.x2,
                .right => cons.x1 = food.x1,
            }
        }

        self.wins[food_idx] = self.wins[self.wins_len - 1];
        self.wins_len -= 1;

        try self.setWin(if (buf[0] == self.wins_len)
            food_idx
        else
            buf[0]);

        return true;
    }

    pub fn rotateInDir(self: *Self, dir: Direction, op_idx: ?usize) !bool {

        const win_idx: usize = op_idx orelse return false;
        // const strength_x: u16 = 8;
        // const strength_y: u16 = 8;

        var my_idxs: [self.wins.len]usize = undefined;
        var your_idxs: [self.wins.len]usize = undefined;

        const idxs_len = self.getAlignedIdxs(dir, win_idx, &my_idxs, &your_idxs)
            orelse return false;

        var area_x1: u16 = 60_000;
        var area_y1: u16 = 60_000;
        var area_x2: u16 = 0;
        var area_y2: u16 = 0;

        for (0..idxs_len.my_idxs_len) |idx| {
            const win = &self.wins[my_idxs[idx]];
            if (win.y1 < area_y1) area_y1 = win.y1;
            if (win.y2 > area_y2) area_y2 = win.y2;
            if (win.x1 < area_x1) area_x1 = win.x1;
            if (win.x2 > area_x2) area_x2 = win.x2;
        }

        for (0..idxs_len.your_idxs_len) |idx| {
            const win = &self.wins[your_idxs[idx]];
            if (win.y1 < area_y1) area_y1 = win.y1;
            if (win.y2 > area_y2) area_y2 = win.y2;
            if (win.x1 < area_x1) area_x1 = win.x1;
            if (win.x2 > area_x2) area_x2 = win.x2;
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
                    const curr = &self.wins[my_idxs[idx]];
                    const prev = &self.wins[my_idxs[idx - 1]];
                    if (curr.y1 != prev.y1 or curr.y2 != prev.y2)
                        return false;
                }
                for (1..idxs_len.your_idxs_len) |idx| {
                    const curr = &self.wins[your_idxs[idx]];
                    const prev = &self.wins[your_idxs[idx - 1]];
                    if (curr.y1 != prev.y1 or curr.y2 != prev.y2)
                        return false;
                }

                // sort idxs
                std.mem.sort(usize, my_idxs[0..idxs_len.my_idxs_len], self.wins, LTX);
                std.mem.sort(usize, your_idxs[0..idxs_len.your_idxs_len], self.wins, LTX);
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
                    const curr = &self.wins[my_idxs[idx]];
                    const prev = &self.wins[my_idxs[idx - 1]];
                    if (curr.x1 != prev.x1 or curr.x2 != prev.x2)
                        return false;
                }
                for (1..idxs_len.your_idxs_len) |idx| {
                    const curr = &self.wins[your_idxs[idx]];
                    const prev = &self.wins[your_idxs[idx - 1]];
                    if (curr.x1 != prev.x1 or curr.x2 != prev.x2)
                        return false;
                }

                // sort idxs
                std.mem.sort(usize, my_idxs[0..idxs_len.my_idxs_len], self.wins, GTY);
                std.mem.sort(usize, your_idxs[0..idxs_len.your_idxs_len], self.wins, GTY);
            },
        }



        var iter: u16 = undefined;
        switch (dir) {
            .up => {
                iter = area_y1;
                for (0..idxs_len.my_idxs_len) |idx| {
                    var win = &self.wins[my_idxs[idx]];
                    win.x1 = area_x1;
                    win.x2 = mid_x;
                    win.y1 = roundToNearest8(iter);
                    iter += (area_y2 - area_y1) / @as(u16, @intCast(idxs_len.my_idxs_len));
                    win.y2 = roundToNearest8(iter);
                }
                iter = area_y1;
                for (0..idxs_len.your_idxs_len) |idx| {
                    var win = &self.wins[your_idxs[idx]];
                    win.x1 = mid_x;
                    win.x2 = area_x2;
                    win.y1 = roundToNearest8(iter);
                    iter += (area_y2 - area_y1) / @as(u16, @intCast(idxs_len.your_idxs_len));
                    win.y2 = roundToNearest8(iter);
                }
            },
            .down => {
                iter = area_y1;
                for (0..idxs_len.my_idxs_len) |idx| {
                    var win = &self.wins[my_idxs[idx]];
                    win.x1 = mid_x;
                    win.x2 = area_x2;
                    win.y1 = roundToNearest8(iter);
                    iter += (area_y2 - area_y1) / @as(u16, @intCast(idxs_len.my_idxs_len));
                    win.y2 = roundToNearest8(iter);
                }
                iter = area_y1;
                for (0..idxs_len.your_idxs_len) |idx| {
                    var win = &self.wins[your_idxs[idx]];
                    win.x1 = area_x1;
                    win.x2 = mid_x;
                    win.y1 = roundToNearest8(iter);
                    iter += (area_y2 - area_y1) / @as(u16, @intCast(idxs_len.your_idxs_len));
                    win.y2 = roundToNearest8(iter);
                }
            },
            .left => {
                iter = area_x1;
                for (0..idxs_len.your_idxs_len) |idx| {
                    var win = &self.wins[your_idxs[idx]];
                    win.y1 = area_y1;
                    win.y2 = mid_y;
                    win.x1 = roundToNearest8(iter);
                    iter += (area_x2 - area_x1) / @as(u16, @intCast(idxs_len.your_idxs_len));
                    win.x2 = roundToNearest8(iter);
                }
                iter = area_x1;
                for (0..idxs_len.my_idxs_len) |idx| {
                    var win = &self.wins[my_idxs[idx]];
                    win.y1 = mid_y;
                    win.y2 = area_y2;
                    win.x1 = roundToNearest8(iter);
                    iter += (area_x2 - area_x1) / @as(u16, @intCast(idxs_len.my_idxs_len));
                    win.x2 = roundToNearest8(iter);
                }
            },
            .right => {
                iter = area_x1;
                for (0..idxs_len.your_idxs_len) |idx| {
                    var win = &self.wins[your_idxs[idx]];
                    win.y1 = mid_y;
                    win.y2 = area_y2;
                    win.x1 = roundToNearest8(iter);
                    iter += (area_x2 - area_x1) / @as(u16, @intCast(idxs_len.your_idxs_len));
                    win.x2 = roundToNearest8(iter);
                }
                iter = area_x1;
                for (0..idxs_len.my_idxs_len) |idx| {
                    var win = &self.wins[my_idxs[idx]];
                    win.y1 = area_y1;
                    win.y2 = mid_y;
                    win.x1 = roundToNearest8(iter);
                    iter += (area_x2 - area_x1) / @as(u16, @intCast(idxs_len.my_idxs_len));
                    win.x2 = roundToNearest8(iter);
                }
            },
        }

        const win = &self.wins[self.win_idx orelse return false];
        const cursor = &win.cursor;
        try self.term.moveCursorTo(
            self.term.fixedFromPercY(win.y1) + cursor.y,
            self.term.fixedFromPercX(win.x1) + cursor.x
        );
        return true;
    }

    pub fn resizeWin(self: *Self, dirp: Direction, op_idx: ?usize, growing: bool) !void {
        var dir = dirp;

        const idx: usize = op_idx orelse return;
        const strength_x: u16 = 8;
        const strength_y: u16 = 8;
        const minCols: u16 = strength_x;
        const minRows: u16 = strength_y;

        var my_idxs: [self.wins.len]usize = undefined;
        var your_idxs: [self.wins.len]usize = undefined;

        var is_growing: bool = growing;

        var op_idxs_len = self.getAlignedIdxs(dir, idx, &my_idxs, &your_idxs);

        // if wall then shrink
        if (op_idxs_len == null) {
            is_growing = false;
            dir = @enumFromInt(@intFromEnum(dir) * -1);
            op_idxs_len = self.getAlignedIdxs(dir, idx, &my_idxs, &your_idxs);
        }

        if (op_idxs_len) |adj| {
            // check bounds
            if (is_growing) {
                for (0..adj.your_idxs_len) |i| {
                    const win = &self.wins[your_idxs[i]];
                    switch (dir) {
                        .up, .down => if (win.y2 - win.y1 <= minRows) return,
                        .left, .right => if (win.x2 - win.x1 <= minCols) return,
                    }
                }
            } else {
                for (0..adj.my_idxs_len) |i| {
                    const win = &self.wins[my_idxs[i]];
                    switch (dir) {
                        .up, .down => if (win.y2 - win.y1 <= minRows) return,
                        .left, .right => if (win.x2 - win.x1 <= minCols) return,
                    }
                }
            }

            for (0..adj.my_idxs_len) |i| {
                var win = &self.wins[my_idxs[i]];
                switch (dir) {
                    .up => {
                        if (is_growing) {
                            win.y1 -= strength_y;
                        } else {
                            win.y1 += strength_y;
                        }
                    },
                    .down => {
                        if (is_growing) {
                            win.y2 += strength_y;
                        } else {
                            win.y2 -= strength_y;
                        }
                    },
                    .left => {
                        if (is_growing) {
                            win.x1 -= strength_x;
                        } else {
                            win.x1 += strength_x;
                        }
                    },
                    .right => {
                        if (is_growing) {
                            win.x2 += strength_x;
                        } else {
                            win.x2 -= strength_x;
                        }
                    },
                }
            }

            for (0..adj.your_idxs_len) |i| {
                var win = &self.wins[your_idxs[i]];
                switch (dir) {
                    .up => {
                        if (is_growing) {
                            win.y2 -= strength_y;
                        } else {
                            win.y2 += strength_y;
                        }
                    },
                    .down => {
                        if (is_growing) {
                            win.y1 += strength_y;
                        } else {
                            win.y1 -= strength_y;
                        }
                    },
                    .left => {
                        if (is_growing) {
                            win.x2 -= strength_x;
                        } else {
                            win.x2 += strength_x;
                        }
                    },
                    .right => {
                        if (is_growing) {
                            win.x1 += strength_x;
                        } else {
                            win.x1 -= strength_x;
                        }
                    },
                }
            }
        }

        const win = &self.wins[self.win_idx orelse return];
        const cursor = &win.cursor;
        try self.term.moveCursorTo(
            self.term.fixedFromPercY(win.y1) + cursor.y,
            self.term.fixedFromPercX(win.x1) + cursor.x
        );
    }

    pub fn swapWinInDir(self: *Self, dir: Direction) !void {
        const curr_win: *Window = &self.wins[self.win_idx orelse return];

        const cursor: *Cursor = &curr_win.cursor;
        const prop_cur_x = self.term.percFromFixedX(cursor.x);
        const prop_cur_y = self.term.percFromFixedY(cursor.y);

        const other_win_idx: usize = self.winIdxFromDirPoint(dir,
            curr_win.x1 + 1 + prop_cur_x,
            curr_win.y1 + 1 + prop_cur_y
        ) orelse return;

        const other_win: *Window = &self.wins[other_win_idx];
        std.mem.swap(u16, &curr_win.x1, &other_win.x1);
        std.mem.swap(u16, &curr_win.y1, &other_win.y1);
        std.mem.swap(u16, &curr_win.x2, &other_win.x2);
        std.mem.swap(u16, &curr_win.y2, &other_win.y2);

        try self.setWin(other_win_idx);
    }

    pub fn setWinFromDir(self: *Self, dir: Direction) !void {
        const win: *Window = &self.wins[self.win_idx orelse return];

        const cursor: *Cursor = &win.cursor;
        const prop_cur_x = self.term.percFromFixedX(cursor.x);
        const prop_cur_y = self.term.percFromFixedY(cursor.y);

        const win_idx: usize = self.winIdxFromDirPoint(dir,
            win.x1 + 1 + prop_cur_x,
            win.y1 + 1 + prop_cur_y
        ) orelse return;

        try self.setWin(win_idx);
    }

    fn winIdxFromDirPoint(self: *Self, dir: Direction, x: u16, y: u16) ?usize {
        const coord_idx = self.winIdxFromPoint(x, y) orelse return null;

        const win: *Window = &self.wins[coord_idx];
        return switch (dir) {
            .up => return self.winIdxFromPoint(x, win.y1 -% 1),
            .down => self.winIdxFromPoint(x, win.y2 + 1),
            .left => self.winIdxFromPoint(win.x1 -% 1, y),
            .right => self.winIdxFromPoint(win.x2 + 1, y),
        };
    }

    fn walk(self: *Self,
        dir: Direction,
        my_border: u16,
        your_border: u16,
        my_win_idx: usize,
        your_win_idx: usize,
        my_idxs_len: *usize,
        my_idxs: *[self.wins.len]usize,
        your_idxs_len: *usize,
        your_idxs: *[self.wins.len]usize,
        isEqual: *const fn (*Window, *Window) bool,
        getShorter: *const fn (*Window, *Window) *Window
    ) void {

        var cur_my_idx: usize = my_win_idx;
        var cur_your_idx: usize = your_win_idx;
        var next_idx: usize = undefined;
        var shorter: *Window = undefined;
        var border: u16 = undefined;

        while (!isEqual(&self.wins[cur_my_idx], &self.wins[cur_your_idx])) {
            shorter = getShorter(&self.wins[cur_my_idx], &self.wins[cur_your_idx]);

            border = if (shorter == &self.wins[cur_my_idx]) my_border else your_border;

            next_idx = self.winIdxFromDirPoint(
                dir,
                if (dir == .up or dir == .down) border else shorter.x1 + 1,
                if (dir == .left or dir == .right) border else shorter.y1 + 1
            ) orelse return;

            if (shorter == &self.wins[cur_my_idx]) {
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
        my_idxs: *[self.wins.len]usize,
        your_idxs: *[self.wins.len]usize
    ) ?struct { my_idxs_len: usize, your_idxs_len: usize } {

        const my_win_idx: usize = idx;
        const my_win: *Window = &self.wins[my_win_idx];

        const your_win_idx: usize = self.winIdxFromDirPoint(
            dir,
            my_win.x1 + 1,
            my_win.y1 + 1
        ) orelse return null;

        const your_win: *Window = &self.wins[your_win_idx];

        var my_idxs_len: usize = 0;
        var your_idxs_len: usize = 0;

        my_idxs[0] = my_win_idx;
        my_idxs_len += 1;
        your_idxs[0] = your_win_idx;
        your_idxs_len += 1;

        const bounds = struct {
            fn equalUp(w1: *Window, w2: *Window) bool {
                return w1.y1 == w2.y1;
            }
            fn shorterUp(w1: *Window, w2: *Window) *Window {
                return if (w1.y1 > w2.y1) w1 else w2;
            }
            fn equalDown(w1: *Window, w2: *Window) bool {
                return w1.y2 == w2.y2;
            }
            fn shorterDown(w1: *Window, w2: *Window) *Window {
                return if (w1.y2 < w2.y2) w1 else w2;
            }
            fn equalLeft(w1: *Window, w2: *Window) bool {
                return w1.x1 == w2.x1;
            }
            fn shorterLeft(w1: *Window, w2: *Window) *Window {
                return if (w1.x1 > w2.x1) w1 else w2;
            }
            fn equalRight(w1: *Window, w2: *Window) bool {
                return w1.x2 == w2.x2;
            }
            fn shorterRight(w1: *Window, w2: *Window) *Window {
                return if (w1.x2 < w2.x2) w1 else w2;
            }
        };

        switch (dir) {
            .right, .left => {
                for ([_]Direction{ .up, .down }) |d| {
                    self.walk(
                        d,
                        if (dir == .right) my_win.x2 - 1 else my_win.x1 + 1,
                        if (dir == .right) your_win.x1 + 1 else your_win.x2 - 1,
                        my_win_idx,
                        your_win_idx,
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
                        if (dir == .down) my_win.y2 - 1 else my_win.y1 + 1,
                        if (dir == .down) your_win.y1 + 1 else your_win.y2 - 1,
                        my_win_idx,
                        your_win_idx,
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

    pub fn winIdxsFromDirWin(self: *Self,
        dir: Direction,
        base_idx: usize, out: *[self.wins.len]usize
    ) ?usize {

        const win: *Window = &self.wins[base_idx];
        var out_len: usize = 0;

        var side_idx: usize = self.winIdxFromDirPoint(dir, win.x1 + 1, win.y1 + 1) orelse return null;

        out[out_len] = side_idx;
        var side_win: *Window = &self.wins[out[out_len]];
        out_len += 1;

        sideiter: switch (dir) {
            .up, .down => {
                if (side_win.x1 != win.x1 or side_win.x2 > win.x2)
                    return null;
                if (side_win.x2 == win.x2)
                    break :sideiter;

                while (true) {
                    const bounds: u16 = if (dir == .up)
                        side_win.y2 - 1
                    else
                        side_win.y1 + 1;

                    side_idx = self.winIdxFromDirPoint(.right, side_win.x1 + 1, bounds) orelse break;

                    out[out_len] = side_idx;
                    side_win = &self.wins[side_idx];
                    out_len += 1;

                    if (side_win.x2 == win.x2)
                        break;
                    if (side_win.x2 > win.x2)
                        return null;
                }
            },
            .left, .right => {
                if (side_win.y1 != win.y1 or side_win.y2 > win.y2)
                    return null;
                if (side_win.y2 == win.y2)
                    break :sideiter;

                while (true) {
                    const bounds: u16 = if (dir == .left)
                        side_win.x2 - 1
                    else
                        side_win.x1 + 1;

                    side_idx = self.winIdxFromDirPoint(.down, bounds, side_win.y1 + 1) orelse break;

                    out[out_len] = side_idx;
                    side_win = &self.wins[side_idx];
                    out_len += 1;

                    if (side_win.y2 == win.y2)
                        break;
                    if (side_win.y2 > win.y2)
                        return null;
                }
            },
        }

        return out_len;
    }
};
