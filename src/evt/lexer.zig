const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const ascii = std.ascii;

const Scanner = @import("scanner.zig");

const Lexer = @This();

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

scanner: Scanner,

pub fn init(source: []const u8) Lexer {
    return .{
        .scanner = Scanner.init(source, " \t\r\n{}()=;:,"),
    };
}

pub fn next(self: *Lexer) !?Token {
    const tok = try self.scanner.next() orelse return null;

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
