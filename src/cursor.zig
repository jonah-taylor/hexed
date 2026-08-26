
pub const Cursor = struct {
    const Self = @This();

    x: u16,
    y: u16,

    pub fn init() Self {
        return .{
            .x = 1,
            .y = 1,
        };
    }
};
