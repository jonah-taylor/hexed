const std = @import("std");
const Terminal = @import("terminal").Terminal;
const Window = @import("window").Window;

pub const Winman = struct {
    const Self = @This();

    stdout: *std.Io.Writer,
    term: *Terminal,
    windows: [10]Window,
    windows_len: usize,
    cur_window: ?*Window,

    pub fn init(stdout: *std.Io.Writer) Self {
        return Self{
            .stdout = stdout,
            .term = undefined,
            .windows = undefined,
            .windows_len = 0,
            .cur_window = null,
        };
    }

    pub fn newWindow(self: *Self, x_loc: u16, y_loc: u16, rows: u16, cols: u16) ?*Window {
        self.windows[self.windows_len] = Window.init(self.stdout, self.term, x_loc, y_loc, rows, cols);
        self.windows_len += 1;
        return &self.windows[self.windows_len - 1];
    }
};
