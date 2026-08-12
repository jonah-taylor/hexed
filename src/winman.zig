const std = @import("std");
const Cursor = @import("cursor").Cursor;
const Terminal = @import("terminal").Terminal;
const Window = @import("window").Window;

// TODO:
// add rotating with a neighbor option
// make rmwin use smallest viable adjacent window as the consumer
// make grow towards a wall shrink in that direction

pub const Direction = enum(i8) {
    up = 1,
    down = -1,
    left = 2,
    right = -2,
};

pub const WinMan = struct {
    const Self = @This();
    const maxWins = 256;

    const err = error {
        NewWinTooSmall,
    };

    stdout: *std.Io.Writer,
    term: *Terminal,
    wins: [maxWins]Window,
    wins_len: usize,
    win_idx: ?usize,


    pub fn init(
        stdout: *std.Io.Writer,
        term: *Terminal)
    Self {
        return Self{
            .stdout = stdout,
            .term = term,
            .wins = undefined,
            .wins_len = 0,
            .win_idx = null,
        };
    }


    pub fn drawWins(self: *Self)
    !void {

        try self.term.saveCursorPos();
        for (0..self.wins_len) |i| {
            try self.wins[i].drawBorder();
        }
        try self.term.loadCursorPos();

    }


    pub fn winIdxFromPoint(self: *Self,
        x_loc: u16,
        y_loc: u16)
    ?usize {

        for (0..self.wins_len) |i| {
            if (self.wins[i].hasCoord(x_loc, y_loc)) {
                return i;
            }
        }
        return null;
    }


    pub fn newWin(self: *Self,
        dir: Direction)
    !void {

        if (self.wins_len >= self.wins.len)
            return;

        var x_loc: u16 = undefined;
        var y_loc: u16 = undefined;
        var rows: u16 = undefined;
        var cols: u16 = undefined;

        if (self.win_idx) |idx| {
            const win: *Window = &self.wins[idx];

            x_loc = win.x_loc;
            y_loc = win.y_loc;
            rows = win.rows;
            cols = win.cols;

            switch (dir) {
                .up, .down => {
                    if (rows / 2 <= 1)
                        return err.NewWinTooSmall;
                },
                .left, .right => {
                    if (cols / 2 <= 1)
                        return err.NewWinTooSmall;
                },
            }

            switch (dir) {
                .up => {
                    rows /= 2;
                    win.y_loc += rows;
                    win.rows = (win.rows + 1) / 2;
                },
                .down => {
                    rows /= 2;
                    win.rows = (win.rows + 1) / 2;
                    y_loc = win.y_loc + win.rows;
                },
                .left => {
                    cols /= 2;
                    win.x_loc += cols;
                    win.cols = (win.cols + 1) / 2;
                },
                .right => {
                    cols /= 2;
                    win.cols = (win.cols + 1) / 2;
                    x_loc = win.x_loc + win.cols;
                },
            }
        } else { // define first window
            x_loc = 0;
            y_loc = 0;
            const term_sz = self.term.getSize();
            rows = term_sz.rows;
            cols = term_sz.cols;
        }


        self.wins[self.wins_len] = Window.init(
            self.stdout,
            self.term,
            x_loc, y_loc,
            rows, cols);

        self.wins_len += 1;
        try self.setWin(self.wins_len - 1);
    }


    pub fn setWin(self: *Self,
        next_idx: ?usize) 
    !void {

        const idx: usize = next_idx orelse return;
        self.win_idx = idx;
        const cur: *Window = &self.wins[idx];

        const cursor: *Cursor = &cur.cursor;
        try self.term.moveCursorTo(
            cur.y_loc + cursor.y_loc, 
            cur.x_loc + cursor.x_loc);
    }


    pub fn winIdxsFromDirWin(self: *Self,
        dir: Direction,
        base_idx: usize,
        out: *[self.wins.len]usize)
    ?usize {

        const win: *Window = &self.wins[base_idx];
        var out_idx: usize = 0;

        var side_idx: usize = self.winIdxFromDirPoint(
            dir,
            win.x_loc,
            win.y_loc) orelse return null;

        out[out_idx] = side_idx;
        var side_win: *Window = &self.wins[out[out_idx]];
        out_idx += 1;

        sideiter: switch (dir) {
            .up, .down => {

                if (side_win.x_loc != win.x_loc or side_win.cols > win.cols)
                    return null;
                if (side_win.x_loc + side_win.cols == win.x_loc + win.cols)
                    break :sideiter;

                while (true) {
                    const bounds: u16 = if (dir == .up)
                            side_win.y_loc + side_win.rows - 1
                        else
                            side_win.y_loc;

                    side_idx = self.winIdxFromDirPoint(.right,
                        side_win.x_loc,
                        bounds) orelse break;

                    out[out_idx] = side_idx;
                    side_win = &self.wins[side_idx];
                    out_idx += 1;

                    if (side_win.x_loc + side_win.cols == win.x_loc + win.cols)
                        break;
                    if (side_win.x_loc + side_win.cols > win.x_loc + win.cols)
                        return null;
                }
            },
            .left, .right => {

                if (side_win.y_loc != win.y_loc or side_win.rows > win.rows)
                    return null;
                if (side_win.y_loc + side_win.rows == win.y_loc + win.rows)
                    break :sideiter;

                while (true) {
                    const bounds: u16 = if (dir == .left)
                            side_win.x_loc + side_win.cols - 1
                        else
                            side_win.x_loc;

                    side_idx = self.winIdxFromDirPoint(
                        .down,
                        bounds,
                        side_win.y_loc) orelse break;

                    out[out_idx] = side_idx;
                    side_win = &self.wins[side_idx];
                    out_idx += 1;

                    if (side_win.y_loc + side_win.rows == win.y_loc + win.rows)
                        break;
                    if (side_win.y_loc + side_win.rows > win.y_loc + win.rows)
                        return null;
                }
            },
        }

        return out_idx;
    }


    pub fn rmWin(self: *Self) !void {
        const food_idx: usize = self.win_idx orelse return;
        const food: *Window = &self.wins[food_idx];

        // neighbors absorbing the awaited empty space
        var consumers: usize = undefined;
        var buf: [self.wins.len]usize = undefined;
        var dir: Direction = undefined;

        for (std.enums.values(Direction)) |d| {
            dir = d;

            consumers = self.winIdxsFromDirWin(
                dir,
                food_idx,
                &buf) orelse continue;

            break;
        } else return;

        switch (dir) {
            .up => for (0..consumers) |i| {
                self.wins[buf[i]].rows += food.rows;
            },
            .down => for (0..consumers) |i| {
                self.wins[buf[i]].rows += food.rows;
                self.wins[buf[i]].y_loc = food.y_loc;
            },
            .left => for (0..consumers) |i| {
                self.wins[buf[i]].cols += food.cols;
            },
            .right => for (0..consumers) |i| {
                self.wins[buf[i]].cols += food.cols;
                self.wins[buf[i]].x_loc = food.x_loc;
            },
        }

        self.wins[food_idx] = self.wins[self.wins_len - 1];
        self.wins_len -= 1;

        try self.setWin(
            if (buf[0] == self.wins_len)
                food_idx
            else buf[0]);
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
        getShorter: *const fn (*Window, *Window) *Window)
    void {

        var cur_my_idx: usize = my_win_idx;
        var cur_your_idx: usize = your_win_idx;
        var next_idx: usize = undefined;
        var shorter: *Window = undefined;
        var border: u16 = undefined;

        while (!isEqual(
            &self.wins[cur_my_idx],
            &self.wins[cur_your_idx])) {

            shorter = getShorter(
                &self.wins[cur_my_idx],
                &self.wins[cur_your_idx]);

            border = if (shorter == &self.wins[cur_my_idx]) my_border else your_border;

            next_idx = self.winIdxFromDirPoint(
                dir,
                if (dir == .up or dir == .down) border else shorter.x_loc,
                if (dir == .left or dir == .right) border else shorter.y_loc
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
        your_idxs: *[self.wins.len]usize)
    ?struct { my_idxs_len: usize, your_idxs_len: usize } {


        const my_win_idx: usize = idx;
        const my_win: *Window = &self.wins[my_win_idx];

        const your_win_idx: usize = self.winIdxFromDirPoint(
            dir,
            my_win.x_loc,
            my_win.y_loc) orelse return null;

        const your_win: *Window = &self.wins[your_win_idx];

        var my_idxs_len: usize = 0;
        var your_idxs_len: usize = 0;

        my_idxs[0] = my_win_idx;
        my_idxs_len += 1;
        your_idxs[0] = your_win_idx;
        your_idxs_len += 1;

        const bounds = struct {
            fn equalUp(w1: *Window, w2: *Window) bool {
                return w1.y_loc == w2.y_loc;
            }
            fn shorterUp(w1: *Window, w2: *Window) *Window {
                return if (w1.y_loc > w2.y_loc) w1 else w2;
            }
            fn equalDown(w1: *Window, w2: *Window) bool {
                return w1.y_loc + w1.rows == w2.y_loc + w2.rows;
            }
            fn shorterDown(w1: *Window, w2: *Window) *Window {
                return if (w1.y_loc + w1.rows < w2.y_loc + w2.rows) w1 else w2;
            }
            fn equalLeft(w1: *Window, w2: *Window) bool {
                return w1.x_loc == w2.x_loc;
            }
            fn shorterLeft(w1: *Window, w2: *Window) *Window {
                return if (w1.x_loc > w2.x_loc) w1 else w2;
            }
            fn equalRight(w1: *Window, w2: *Window) bool {
                return w1.x_loc + w1.cols == w2.x_loc + w2.cols;
            }
            fn shorterRight(w1: *Window, w2: *Window) *Window {
                return if (w1.x_loc + w1.cols < w2.x_loc + w2.cols) w1 else w2;
            }
        };

        switch (dir) {
            .right, .left => {
                for ([_]Direction{ .up, .down}) |d| {
                    self.walk(
                        d,
                        if (dir == .right) my_win.x_loc + my_win.cols - 1 else my_win.x_loc,
                        if (dir == .right) your_win.x_loc else your_win.x_loc + your_win.cols - 1,
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
                for ([_]Direction{ .left, .right}) |d| {
                    self.walk(
                        d,
                        if (dir == .down) my_win.y_loc + my_win.rows - 1 else my_win.y_loc,
                        if (dir == .down) your_win.y_loc else your_win.y_loc + your_win.rows - 1,
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

        return .{ .my_idxs_len=my_idxs_len, .your_idxs_len=your_idxs_len};
    }


    pub fn resizeWin(self: *Self,
        dir: Direction,
        op_idx: ?usize,
        isGrowing: bool)
    !void {

        const idx: usize = op_idx orelse return;
        const strength: u16 = 1;
        const minWinLen: u16 = strength + 2;

        var my_idxs: [self.wins.len]usize = undefined;
        var your_idxs: [self.wins.len]usize = undefined;

        const op_idxs_len = self.getAlignedIdxs(
            dir,
            idx,
            &my_idxs, &your_idxs);


        if (op_idxs_len) |adj| {

            // check bounds
            for (0..adj.your_idxs_len) |i| {
                switch (dir) {
                    .up, .down => if (self.wins[your_idxs[i]].rows < minWinLen) return,
                    .left, .right => if (self.wins[your_idxs[i]].cols < minWinLen) return,
                }
            }

            for (0..adj.my_idxs_len) |i| {
                switch (dir) {
                    .up => {
                        if (isGrowing) {
                            self.wins[my_idxs[i]].y_loc -= strength;
                            self.wins[my_idxs[i]].rows += strength;
                        } else {
                            self.wins[my_idxs[i]].y_loc += strength;
                            self.wins[my_idxs[i]].rows -= strength;
                        }
                    },
                    .down => {
                        if (isGrowing) {
                            self.wins[my_idxs[i]].rows += strength;
                        } else {
                            self.wins[my_idxs[i]].rows -= strength;
                        }
                    },
                    .left => {
                        if (isGrowing) {
                            self.wins[my_idxs[i]].x_loc -= strength;
                            self.wins[my_idxs[i]].cols += strength;
                        } else {
                            self.wins[my_idxs[i]].x_loc += strength;
                            self.wins[my_idxs[i]].cols -= strength;
                        }
                    },
                    .right => {
                        if (isGrowing) {
                            self.wins[my_idxs[i]].cols += strength;
                        } else {
                            self.wins[my_idxs[i]].cols -= strength;
                        }
                    },
                }
            }
            for (0..adj.your_idxs_len) |i| {
                switch (dir) {
                    .up => {
                        if (isGrowing) {
                            self.wins[your_idxs[i]].rows -= strength;
                        } else {
                            self.wins[your_idxs[i]].rows += strength;
                        }
                    },
                    .down => {
                        if (isGrowing) {
                            self.wins[your_idxs[i]].y_loc += strength;
                            self.wins[your_idxs[i]].rows -= strength;
                        } else {
                            self.wins[your_idxs[i]].y_loc -= strength;
                            self.wins[your_idxs[i]].rows += strength;
                        }
                    },
                    .left => {
                        if (isGrowing) {
                            self.wins[your_idxs[i]].cols -= strength;
                        } else {
                            self.wins[your_idxs[i]].cols += strength;
                        }
                    },
                    .right => {
                        if (isGrowing) {
                            self.wins[your_idxs[i]].x_loc += strength;
                            self.wins[your_idxs[i]].cols -= strength;
                        } else {
                            self.wins[your_idxs[i]].x_loc -= strength;
                            self.wins[your_idxs[i]].cols += strength;
                        }
                    },
                }
            }
        }
    }
 

    pub fn setWinFromDir(self: *Self,
        dir: Direction)
    !void {

        const win: *Window = &self.wins[self.win_idx orelse return];
        const cursor: *Cursor = &win.cursor;
        const win_idx: usize = self.winIdxFromDirPoint(
            dir,
            win.x_loc + cursor.x_loc,
            win.y_loc + cursor.y_loc) orelse return;

        try self.setWin(win_idx);
    }


    fn winIdxFromDirPoint(self: *Self,
        dir: Direction,
        x_loc: u16, y_loc: u16)
    ?usize {

        const coord_idx = self.winIdxFromPoint(
            x_loc, y_loc) orelse return null;

        const win: *Window = &self.wins[coord_idx];
         return switch (dir) {
            .up => return self.winIdxFromPoint(x_loc, win.y_loc -% 1),
            .down => self.winIdxFromPoint(x_loc, win.y_loc + win.rows),
            .left => self.winIdxFromPoint(win.x_loc -% 1, y_loc),
            .right => self.winIdxFromPoint(win.x_loc + win.cols, y_loc),
        };
    }
};
