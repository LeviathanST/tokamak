const std = @import("std");

pub const Buf = @import("util/buf.zig").Buf;
pub const SlotMap = @import("util/slotmap.zig").SlotMap;
pub const SmolStr = @import("util/smolstr.zig").SmolStr;
pub const Smol128 = @import("util/smolstr.zig").Smol128;
pub const Smol192 = @import("util/smolstr.zig").Smol192;
pub const Smol256 = @import("util/smolstr.zig").Smol256;

pub const whitespace = std.ascii.whitespace;

pub fn trim(slice: []const u8) []const u8 {
    return std.mem.trim(u8, slice, &whitespace);
}
