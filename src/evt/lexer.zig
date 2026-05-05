const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;

pub const Token = union(enum) {
    EventKeyword,
    TypeKeyword,
    StructKeyword,

    Identifier: []const u8,
    Length: usize,

    OpenBrace,
    CloseBrace,
    OpenParen,
    CloseParen,
    Equal,
    Colon,
    Semicolon,
    Comma,
};

pub const Lexer = @This();

const table: [256]bool = blk: {
    var t = [_]bool{false} ** 256;
    for (" \r\n\t{}[]=:;,") |s| t[s] = true;
    break :blk t;
};

stream: []const u8,
pos: usize,

pub fn init(stream: []const u8) Lexer {
    return .{ .stream = stream, .pos = 0 };
}

pub fn reset(self: *Lexer) void {
    self.pos = 0;
}

fn scan(self: *Lexer) !?union(enum) {
    blob: []const u8,
    symbol: u8,
} {
    if (self.pos >= self.stream.len) return null;

    if (table[self.stream[self.pos]]) {
        const c = self.stream[self.pos];
        self.pos += 1;
        return .{ .symbol = c };
    }

    const start = self.pos;
    while (self.pos < self.stream.len and !table[self.stream[self.pos]])
        self.pos += 1;

    return .{ .blob = self.stream[start..self.pos] };
}

pub fn next(self: *Lexer) !?Token {
    const tok = try self.scan() orelse return null;

    switch (tok) {
        .symbol => |c| {
            return switch (c) {
                '{' => .OpenBrace,
                '}' => .CloseBrace,
                '(' => .OpenParen,
                ')' => .CloseParen,
                '=' => .Equal,
                ':' => .Colon,
                ';' => .Semicolon,
                ',' => .Comma,
                ' ', '\t', '\r', '\n' => return self.next(),
                else => return error.InvalidSymbol,
            };
        },
        .blob => |text| {
            if (mem.eql(u8, text, "event")) return .EventKeyword;
            if (mem.eql(u8, text, "type")) return .TypeKeyword;
            if (mem.eql(u8, text, "struct")) return .StructKeyword;

            // try to parse as a length
            const length = fmt.parseInt(usize, text, 0) catch return .{ .Identifier = text };
            return .{ .Length = length };
        },
    }
}
