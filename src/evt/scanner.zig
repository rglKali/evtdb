const std = @import("std");
const mem = std.mem;
const math = std.math;

const Scanner = @This();
stream: []const u8,
delim: []const u8,
pos: usize,

pub const BlobOrSymbol = union(enum) {
    blob: []const u8,
    symbol: u8,
};

pub fn init(stream: []const u8, delim: []const u8) Scanner {
    return .{
        .stream = stream,
        .delim = delim,
        .pos = 0,
    };
}

fn isDelim(self: *Scanner) bool {
    if (self.pos >= self.stream.len) return false;
    for (self.delim) |d| {
        if (self.stream[self.pos] == d) return true;
    }
    return false;
}

pub fn next(self: *Scanner) !?BlobOrSymbol {
    if (self.pos >= self.stream.len) return null;

    if (self.isDelim()) {
        const c = self.stream[self.pos];
        self.pos += 1;
        return .{ .symbol = c };
    }

    const start = self.pos;
    while (self.pos < self.stream.len and !self.isDelim())
        self.pos += 1;

    const text = self.stream[start..self.pos];
    return .{ .blob = text };
}
