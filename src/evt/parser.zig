const std = @import("std");
const mem = std.mem;

const Lexer = @import("lexer.zig");
const Token = Lexer.Token;

pub const Identifier = []const u8;

pub const Field = struct {
    name: []const u8,
    typ: Value,
};

pub const Array = struct {
    size: u64,
    typ: *Value,
};

pub const Value = union(enum) {
    Struct: []Field,
    Union: []Field,
    Enum: []Identifier,
    Ident: Identifier,
    Array: Array,
};

pub const Entry = struct {
    name: Identifier,
    value: Value,
};

pub const Symtab = struct {
    types: []Entry,
    events: []Entry,
};

const Parser = struct {
    alloc: mem.Allocator,
    lexer: *Lexer,
    peeked: ?Token = null,

    fn peek(self: *Parser) !?Token {
        if (self.peeked == null)
            self.peeked = try self.lexer.next();
        return self.peeked;
    }

    fn advance(self: *Parser) !?Token {
        if (self.peeked) |t| {
            self.peeked = null;
            return t;
        }
        return self.lexer.next();
    }

    fn expectIdent(self: *Parser) ![]const u8 {
        const t = try self.advance() orelse return error.UnexpectedEof;
        if (t == .Identifier) |s| return s;
        return error.UnexpectedToken;
    }

    fn expectLength(self: *Parser) !usize {
        const t = try self.advance() orelse return error.UnexpectedEof;
        if (t == .Length) |n| return n;
        return error.UnexpectedToken;
    }

    fn expectTag(self: *Parser, tag: Token) !void {
        const t = try self.advance() orelse return error.UnexpectedEof;
        // Compare active tags via std.meta.activeTag.
        if (std.meta.activeTag(t) != std.meta.activeTag(tag))
            return error.UnexpectedToken;
    }

    fn parseValue(self: *Parser) !Value {
        const t = try self.advance() orelse return error.UnexpectedEof;
        return switch (t) {
            .StructKeyword => .{ .Struct = try self.parseFields() },
            .UnionKeyword => .{ .Union = try self.parseFields() },
            .EnumKeyword => .{ .Enum = try self.parseEnumBody() },
            .Identifier => |s| .{ .Ident = s },
            // '[' length ']' value
            .OpenParen => blk: {
                const size = try self.expectLength();
                try self.expectTag(.CloseParen);
                const val = try self.parseValue();
                break :blk .{ .Array = .{ .size = size, .typ = val } };
            },
            else => error.UnexpectedToken,
        };
    }

    // '{' (ident ':' value (',' ident ':' value)*)? '}'
    fn parseFields(self: *Parser) ![]Field {
        try self.expectTag(.OpenBrace);
        var list: std.ArrayList(Field) = .empty;
        defer list.deinit(self.alloc);

        while (true) {
            const t = try self.peek() orelse return error.UnexpectedEof;
            if (t == .CloseBrace) {
                _ = try self.advance();
                break;
            }

            const name = try self.expectIdent();
            try self.expectTag(.Colon);
            const typ = try self.parseValue();
            try list.append(self.alloc, .{ .name = name, .typ = typ });

            const sep = try self.peek() orelse return error.UnexpectedEof;
            if (sep == .Comma) _ = try self.advance();
        }

        return list.toOwnedSlice(self.alloc);
    }

    // '{' ident (',' ident)* '}'
    fn parseEnumBody(self: *Parser) ![]Identifier {
        try self.expectTag(.OpenBrace);
        var list: std.ArrayList(Identifier) = .empty;
        defer list.deinit(self.alloc);

        while (true) {
            const t = try self.peek() orelse return error.UnexpectedEof;
            if (t == .CloseBrace) {
                _ = try self.advance();
                break;
            }

            try list.append(self.alloc, try self.expectIdent());

            const sep = try self.peek() orelse return error.UnexpectedEof;
            if (sep == .Comma) _ = try self.advance();
        }

        return list.toOwnedSlice(self.alloc);
    }

    // ident '=' value ';'
    fn parseEntry(self: *Parser) !Entry {
        const name = try self.expectIdent();
        try self.expectTag(.Equal);
        const value = try self.parseValue();
        try self.expectTag(.Semicolon);
        return .{ .name = name, .value = value };
    }

    // (('type' | 'event') entry)*
    fn parseSymtab(self: *Parser) !Symtab {
        var types: std.ArrayList(Entry) = .empty;
        var events: std.ArrayList(Entry) = .empty;
        defer types.deinit(self.alloc);
        defer events.deinit(self.alloc);

        while (true) {
            const t = try self.advance() orelse break;
            switch (t) {
                .TypeKeyword => try types.append(self.alloc, try self.parseEntry()),
                .EventKeyword => try events.append(self.alloc, try self.parseEntry()),
                else => return error.UnexpectedToken,
            }
        }

        return .{
            .types = try types.toOwnedSlice(self.alloc),
            .events = try events.toOwnedSlice(self.alloc),
        };
    }
};

pub fn parse(alloc: mem.Allocator, lexer: *Lexer) !Symtab {
    var p = Parser{ .alloc = alloc, .lexer = lexer };
    return p.parseSymtab();
}
