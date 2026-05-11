const std = @import("std");
const meta = std.meta;
const mem = std.mem;
const fmt = std.fmt;
const ascii = std.ascii;

const schema = @import("../schema.zig");

const Token = union(enum) {
    TypeKeyword,

    StructKeyword,
    UnionKeyword,
    EnumKeyword,

    Ident: []const u8,
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

const Lexer = struct {
    const table: [256]bool = blk: {
        var t = [_]bool{false} ** 256;
        for (" \r\n\t{}[]=:;,") |s| t[s] = true;
        break :blk t;
    };

    stream: []const u8,
    pos: usize,

    fn init(stream: []const u8) Lexer {
        return .{ .stream = stream, .pos = 0 };
    }

    fn scan(self: *Lexer) ?union(enum) { blob: []const u8, symbol: u8 } {
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

    fn next(self: *Lexer) schema.Error!?Token {
        const tok = self.scan() orelse return null;

        switch (tok) {
            .symbol => |c| {
                return switch (c) {
                    '{' => .OpenBrace,
                    '}' => .CloseBrace,
                    '[' => .OpenParen,
                    ']' => .CloseParen,
                    '=' => .Equal,
                    ':' => .Colon,
                    ';' => .Semicolon,
                    ',' => .Comma,
                    ' ', '\t', '\r', '\n' => return self.next(),
                    else => return schema.Error.schema.Error,
                };
            },

            .blob => |text| {
                if (mem.eql(u8, text, "type")) return .TypeKeyword;
                if (mem.eql(u8, text, "struct")) return .StructKeyword;
                if (mem.eql(u8, text, "union")) return .UnionKeyword;
                if (mem.eql(u8, text, "enum")) return .EnumKeyword;

                // if starts with a digit, then treat as length, otherwise treat as identifier
                if (ascii.isDigit(text[0])) {
                    const length = fmt.parseUnsigned(usize, text, 0) catch return schema.Error.schema.Error;
                    return .{ .Length = length };
                }

                for (text) |c|
                    if (c != '_' and !ascii.isAlphanumeric(c))
                        return schema.Error.schema.Error;

                return .{ .Ident = text };
            },
        }
    }
};

const Parser = struct {
    alloc: mem.Allocator,
    stream: Lexer,
    peeked: ?Token,

    fn init(alloc: mem.Allocator, stream: []const u8) Parser {
        return .{ .alloc = alloc, .stream = Lexer.init(alloc, stream), .peeked = null };
    }

    fn peek(self: *Parser) schema.Error!?Token {
        if (self.peeked) return self.peeked.?;
        self.peeked = self.stream.next() orelse null;
        return self.peeked.?;
    }

    fn advance(self: *Parser) schema.Error!?Token {
        if (self.peeked) {
            const t = self.peeked.?;
            self.peeked = null;
            return t;
        }
        return self.stream.next() orelse null;
    }

    fn advanceIf(self: *Parser, expected: Token) schema.Error!bool {
        const t = try self.peek() orelse return schema.Error.SyntaxError;
        if (t != expected)
            return false;

        _ = try self.advance();
        return true;
    }

    fn expect(self: *Parser) schema.Error!Token {
        return try self.advance() orelse return schema.Error.UnexpectedEof;
    }

    fn expectIdent(self: *Parser) schema.Error![]const u8 {
        const t = try self.expect();
        switch (t) {
            .Identifier => |s| return self.alloc.dupe(u8, s),
            else => return schema.Error.SyntaxError,
        }
    }

    fn expectLength(self: *Parser) schema.Error!usize {
        const t = try self.expect();
        switch (t) {
            .Length => |n| return n,
            else => return schema.Error.SyntaxError,
        }
    }

    fn expectTag(self: *Parser, tag: Token) schema.Error!void {
        const t = try self.expect();
        // Compare active tags via meta.activeTag.
        if (meta.activeTag(t) != meta.activeTag(tag))
            return schema.Error.SyntaxError;
    }

    fn createArray(self: *Parser, size: usize, value: schema.Type) schema.Error!schema.Array {
        const arr = try self.alloc.create(schema.Array);
        arr.size = size;
        arr.value = value;
        return arr;
    }

    fn parseValue(self: *Parser) schema.Error!schema.Type {
        const t = try self.expect();
        return switch (t) {
            .StructKeyword => .{ .Struct = try self.parseFields() },
            .UnionKeyword => .{ .Union = try self.parseFields() },
            .EnumKeyword => .{ .Enum = try self.parseEnum() },
            .Identifier => |s| .{ .Ident = try self.alloc.dupe(u8, s) },
            // '[' length ']' value
            .OpenParen => blk: {
                const size = try self.expectLength();
                try self.expectTag(.CloseParen);
                const val = try self.parseValue();
                errdefer schema.freeType(self.alloc, val);
                break :blk .{ .Array = try self.createArray(size, val) };
            },
            else => schema.Error.SyntaxError,
        };
    }

    // '{' (ident ':' value (',' ident ':' value)*)? '}'
    fn parseFields(self: *Parser) schema.Error![]schema.Entry {
        try self.expectTag(.OpenBrace);
        var list: std.ArrayList(schema.Entry) = .empty;
        errdefer {
            for (list.items) |e| schema.freeEntry(self.alloc, e);
            list.deinit(self.alloc);
        }

        while (true) {
            if (try self.advanceIf(.CloseBrace))
                break;

            const name = try self.expectIdent();
            errdefer schema.freeIdentifier(self.alloc, name);

            try self.expectTag(.Colon);
            const typ = try self.parseValue();
            errdefer schema.freeType(self.alloc, typ);

            _ = try self.advanceIf(.Comma);
            try list.append(self.alloc, .{ .key = name, .value = typ });
        }

        return list.toOwnedSlice(self.alloc);
    }

    // '{' ident (',' ident)* '}'
    fn parseEnum(self: *Parser) schema.Error![]schema.Identifier {
        try self.expectTag(.OpenBrace);
        var list: std.ArrayList(schema.Identifier) = .empty;
        errdefer {
            for (list.items) |id| schema.freeIdentifier(self.alloc, id);
            list.deinit(self.alloc);
        }

        while (true) {
            if (try self.advanceIf(.CloseBrace))
                break;

            const ident = try self.expectIdent();
            errdefer schema.freeIdentifier(self.alloc, ident);

            _ = try self.advanceIf(.Comma);
            try list.append(self.alloc, ident);
        }

        return list.toOwnedSlice(self.alloc);
    }

    // type ident '=' value ';'
    fn parseEntry(self: *Parser) schema.Error!schema.Entry {
        try self.expectTag(.TypeKeyword);

        const name = try self.expectIdent();
        errdefer schema.freeIdentifier(self.alloc, name);

        try self.expectTag(.Equal);
        const value = try self.parseValue();
        errdefer schema.freeType(self.alloc, value);

        try self.expectTag(.Semicolon);
        return .{ .key = name, .value = value };
    }

    fn next(self: *Parser) schema.Error!?schema.Entry {
        _ = try self.peek() orelse return null;
        return self.parseEntry();
    }
};

pub fn parse(alloc: mem.Allocator, stream: []const u8) schema.Error!?[]schema.Entry {
    var p = Parser.init(alloc, stream);
    var list: std.ArrayList(schema.Entry) = .empty;
    errdefer {
        for (list.items) |e| schema.freeEntry(alloc, e);
        list.deinit(alloc);
    }

    while (true) {
        const entry = try p.next() orelse break;
        list.append(alloc, entry) catch |err| {
            schema.freeEntry(alloc, entry);
            return err;
        };
    }

    return list.toOwnedSlice(alloc);
}

pub fn parser() schema.Parser {
    return &parse;
}
