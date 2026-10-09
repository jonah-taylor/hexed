
pub const Cursor = struct {
    const Self = @This();

    x: u16,
    y: u16,

    ln: u16,
    ch: u16,

    ideal_ch: u16,

    pub fn init() Self {
        return .{
            .x = 1,
            .y = 1,
            .ln = 1,
            .ch = 1,
            .ideal_ch = 1,
        };
    }
};

