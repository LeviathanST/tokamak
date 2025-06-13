// private (for now)

const std = @import("std");

pub fn SlotMap(comptime T: type) type {
    return struct {
        pages: []Page,

        pub const Id = packed struct(u64) {
            gen: u32,
            index: u32,
        };

        pub const Slot = struct {
            gen: u32,
            value: T,
        };

        pub const Page = struct {
            used: u64, // bitset
            slots: [64]Slot,
        };

        pub const Iterator = struct {
            map: *const SlotMap(T),
            index: u32 = 0,

            pub const Entry = struct {
                id: Id,
                value: *const T,
            };

            pub fn next(self: *Iterator) ?Entry {
                for (self.map.pages[(self.index / 64)..]) |*page| {
                    for ((self.index % 64)..64) |si| {
                        defer self.index += 1;

                        if (page.used & @as(u64, 1) << @as(u6, @intCast(si)) != 0) {
                            return .{
                                .id = .{
                                    .gen = page.slots[si].gen,
                                    .index = self.index,
                                },
                                .value = &page.slots[si].value,
                            };
                        }
                    } else self.index += 64;
                }

                return null;
            }
        };

        pub fn init(pages: []Page) @This() {
            for (pages) |*p| {
                p.used = 0;
                for (&p.slots) |*s| s.gen = 1;
            }

            return .{
                .pages = pages,
            };
        }

        pub fn initAlloc(allocator: std.mem.Allocator, n_pages: usize) !@This() {
            return init(
                try allocator.alloc(Page, n_pages),
            );
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.pages);
        }

        pub fn insert(self: *@This(), value: T) !Id {
            for (self.pages, 0..) |*p, pi| {
                // Skip full
                if (p.used == ~@as(u64, 0)) continue;

                for (0..64) |si| {
                    const mask = @as(u64, 1) << @as(u6, @intCast(si));

                    // Check if slot is free and not exhausted (gen != 0)
                    if (p.used & mask == 0 and p.slots[si].gen != 0) {
                        p.used |= mask;
                        p.slots[si].value = value;

                        return .{
                            .gen = p.slots[si].gen,
                            .index = @intCast(pi * 64 + si),
                        };
                    }
                }
            } else return error.Overflow;
        }

        pub fn find(self: *@This(), id: Id) ?*T {
            if (self.findSlot(id.index)) |slot| {
                if (slot.gen == id.gen) {
                    return &slot.value;
                }
            }

            return null;
        }

        pub fn remove(self: *@This(), id: Id) void {
            if (self.findSlot(id.index)) |slot| {
                if (slot.gen == id.gen) {
                    self.pages[id.index % 64].used &= ~@as(u64, 1) << @as(u6, @intCast(id.index % 64));
                    slot.gen +%= 1; // overflow to zero means the slot is exhausted and can't be used anymore
                }
            }
        }

        pub fn iter(self: *const @This()) Iterator {
            return Iterator{
                .map = self,
            };
        }

        fn findSlot(self: *@This(), index: u32) ?*Slot {
            const page = index / 64;
            const slot = index % 64;

            if (page < self.pages.len) {
                const mask = @as(u64, 1) << @as(u6, @intCast(slot));

                if (self.pages[page].used & mask != 0) {
                    return &self.pages[page].slots[slot];
                }
            }

            return null;
        }
    };
}

test SlotMap {
    var buf: [2]SlotMap(usize).Page = undefined;
    var map = SlotMap(usize).init(&buf);

    const id = try map.insert(123);
    try std.testing.expectEqual(123, map.find(id).?.*);

    map.remove(id);
    try std.testing.expectEqual(null, map.find(id));

    for (0..128) |i| {
        const id2 = try map.insert(i);
        // Test fails here: attempt to use null
        try std.testing.expectEqual(i, map.find(id2).?.*);
    }

    var it = map.iter();
    var j: usize = 0;
    while (it.next()) |entry| : (j += 1) {
        try std.testing.expectEqual(j, entry.value.*);
    }

    try std.testing.expectError(error.Overflow, map.insert(128));
}

pub fn Buf(comptime T: type) type {
    return struct {
        buf: []T = &.{},
        len: usize = 0,

        /// Init with an already existing slice
        pub fn init(buf: []T) @This() {
            return .{ .buf = buf };
        }

        /// Init at comptime (capacity needs to be known in advance)
        pub fn initComptime(comptime capacity: usize) @This() {
            var buf: [capacity]T = undefined;
            return .{ .buf = &buf };
        }

        /// Init with newly created slice
        pub fn initAlloc(allocator: std.mem.Allocator, capacity: usize) !@This() {
            const buf = try allocator.alloc(T, capacity);
            return .{ .buf = buf };
        }

        /// Deinit (runtime-only)
        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.buf);
        }

        /// Insert one item at the end.
        pub fn push(self: *@This(), v: T) void {
            self.buf[self.len] = v;
            self.len += 1;
        }

        /// Remove and return the last item.
        pub fn pop(self: *@This()) ?T {
            if (self.len == 0) return null;
            self.len -= 1;
            return self.buf[self.len];
        }

        pub fn insert(self: *@This(), index: usize, item: T) void {
            self.insertSlice(index, &.{item});
        }

        pub fn insertSlice(self: *@This(), index: usize, slice: []const T) void {
            std.debug.assert(index < self.len);
            std.debug.assert(self.buf.len >= self.len + slice.len);

            std.mem.copyBackwards(T, self.buf[index + slice.len ..], self.items()[index..]);
            @memcpy(self.buf[index .. index + slice.len], slice);
            self.len += slice.len;
        }

        /// Get the current slice
        pub fn items(self: *@This()) []T {
            return self.buf[0..self.len];
        }

        /// Return the final result
        pub fn finish(self: *@This()) []const T {
            if (@inComptime()) {
                const copy = self.buf[0..self.len].*;
                return &copy;
            } else {
                std.debug.assert(self.len == self.buf.len);
                return self.items();
            }
        }
    };
}

test Buf {
    var buf = try Buf(u8).initAlloc(std.testing.allocator, 7);
    defer buf.deinit(std.testing.allocator);

    buf.push(0);
    buf.insertSlice(0, &.{ 1, 2 });
    buf.push(3);
    buf.insertSlice(buf.len - 1, &.{ 4, 5 });
    buf.insert(2, 6);

    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 6, 0, 4, 5, 3 }, buf.items());
}
