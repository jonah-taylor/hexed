
pub const Rectangle = struct {
    x1: u16,
    y1: u16,
    x2: u16,
    y2: u16,
};

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
