const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;

pub const SyntaxError = error{
    OutOfMemory,
    InvalidSymbol,
    UnexpectedEof,
    UnexpectedToken,
    CycleDetected,
};

pub const Token = union(enum) {
    TypeKeyword,
    EventKeyword,

    StructKeyword,
    UnionKeyword,
    EnumKeyword,

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

pub const Lexer = struct {
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

    fn scan(self: *Lexer) SyntaxError!?union(enum) {
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
                    '[' => .OpenParen,
                    ']' => .CloseParen,
                    '=' => .Equal,
                    ':' => .Colon,
                    ';' => .Semicolon,
                    ',' => .Comma,
                    ' ', '\t', '\r', '\n' => return self.next(),
                    else => return SyntaxError.InvalidSymbol,
                };
            },
            .blob => |text| {
                if (mem.eql(u8, text, "type")) return .TypeKeyword;
                if (mem.eql(u8, text, "event")) return .EventKeyword;

                if (mem.eql(u8, text, "struct")) return .StructKeyword;
                if (mem.eql(u8, text, "union")) return .UnionKeyword;
                if (mem.eql(u8, text, "enum")) return .EnumKeyword;

                // try to parse as a length
                const length = fmt.parseInt(usize, text, 0) catch return .{ .Identifier = text };
                return .{ .Length = length };
            },
        }
    }
};

pub const Identifier = []const u8;

pub const Array = struct {
    size: u64,
    value: Value,
};

pub const Entry = struct {
    name: Identifier,
    value: Value,
};

pub const Value = union(enum) {
    Struct: []Entry,
    Union: []Entry,
    Enum: []Identifier,
    Ident: Identifier,
    Array: *Array,
};

pub const Symtab = struct {
    types: []Entry,
    events: []Entry,
};

pub const Parser = struct {
    alloc: mem.Allocator,
    lexer: Lexer,
    peeked: ?Token = null,

    pub fn init(alloc: mem.Allocator, lexer: Lexer) Parser {
        return .{ .alloc = alloc, .lexer = lexer, .peeked = null };
    }

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

    fn expectIdent(self: *Parser) SyntaxError![]const u8 {
        const t = try self.advance() orelse return SyntaxError.UnexpectedEof;
        switch (t) {
            .Identifier => |s| return self.alloc.dupe(u8, s),
            else => return SyntaxError.UnexpectedToken,
        }
    }

    fn expectLength(self: *Parser) SyntaxError!usize {
        const t = try self.advance() orelse return SyntaxError.UnexpectedEof;
        switch (t) {
            .Length => |n| return n,
            else => return SyntaxError.UnexpectedToken,
        }
    }

    fn expectTag(self: *Parser, tag: Token) SyntaxError!void {
        const t = try self.advance() orelse return SyntaxError.UnexpectedEof;
        // Compare active tags via std.meta.activeTag.
        if (std.meta.activeTag(t) != std.meta.activeTag(tag))
            return SyntaxError.UnexpectedToken;
    }

    fn parseValue(self: *Parser) SyntaxError!Value {
        const t = try self.advance() orelse return SyntaxError.UnexpectedEof;
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
                const arr = try self.alloc.create(Array);
                arr.size = size;
                arr.value = val;
                break :blk .{ .Array = arr };
            },
            else => SyntaxError.UnexpectedToken,
        };
    }

    // '{' (ident ':' value (',' ident ':' value)*)? '}'
    fn parseFields(self: *Parser) SyntaxError![]Entry {
        try self.expectTag(.OpenBrace);
        var list: std.ArrayList(Entry) = .empty;
        defer list.deinit(self.alloc);

        while (true) {
            const t = try self.peek() orelse return SyntaxError.UnexpectedEof;
            if (t == .CloseBrace) {
                _ = try self.advance();
                break;
            }

            const name = try self.expectIdent();
            try self.expectTag(.Colon);
            const typ = try self.parseValue();
            try list.append(self.alloc, .{ .name = name, .value = typ });

            const sep = try self.peek() orelse return SyntaxError.UnexpectedEof;
            if (sep == .Comma) _ = try self.advance();
        }

        return list.toOwnedSlice(self.alloc);
    }

    // '{' ident (',' ident)* '}'
    fn parseEnumBody(self: *Parser) SyntaxError![]Identifier {
        try self.expectTag(.OpenBrace);
        var list: std.ArrayList(Identifier) = .empty;
        defer list.deinit(self.alloc);

        while (true) {
            const t = try self.peek() orelse return SyntaxError.UnexpectedEof;
            if (t == .CloseBrace) {
                _ = try self.advance();
                break;
            }

            try list.append(self.alloc, try self.expectIdent());

            const sep = try self.peek() orelse return SyntaxError.UnexpectedEof;
            if (sep == .Comma) _ = try self.advance();
        }

        return list.toOwnedSlice(self.alloc);
    }

    // ident '=' value ';'
    fn parseEntry(self: *Parser) SyntaxError!Entry {
        const name = try self.expectIdent();
        try self.expectTag(.Equal);
        const value = try self.parseValue();
        try self.expectTag(.Semicolon);
        return .{ .name = name, .value = value };
    }

    // (('type' | 'event') entry)*
    pub fn parse(self: *Parser) SyntaxError!Symtab {
        var types: std.ArrayList(Entry) = .empty;
        var events: std.ArrayList(Entry) = .empty;
        defer types.deinit(self.alloc);
        defer events.deinit(self.alloc);

        while (true) {
            const t = try self.advance() orelse break;
            switch (t) {
                .TypeKeyword => try types.append(self.alloc, try self.parseEntry()),
                .EventKeyword => try events.append(self.alloc, try self.parseEntry()),
                else => return SyntaxError.UnexpectedToken,
            }
        }

        return .{
            .types = try types.toOwnedSlice(self.alloc),
            .events = try events.toOwnedSlice(self.alloc),
        };
    }
};

pub const Validator = struct {
    visited: std.StringHashMap(bool),
    types: std.StringHashMap(Value),

    pub fn init(alloc: mem.Allocator, symtab: Symtab) !Validator {
        const visited = std.StringHashMap(bool).init(alloc);
        var types = std.StringHashMap(Value).init(alloc);

        for (symtab.types) |entry| {
            try types.put(entry.name, entry.value);
        }
        for (symtab.events) |entry| {
            try types.put(entry.name, entry.value);
        }

        return .{ .visited = visited, .types = types };
    }

    pub fn deinit(self: *Validator) void {
        self.visited.deinit();
        self.types.deinit();
    }

    fn visitValue(self: *Validator, value: Value) SyntaxError!void {
        switch (value) {
            .Ident => |ident| try self.visitIdent(ident),
            .Array => |arr| try self.visitValue(arr.value),
            .Struct, .Union => |fields| for (fields) |field| try self.visitEntry(field),
            .Enum => {}, // leaf — identifiers are just names, no type refs
        }
    }

    fn visitEntry(self: *Validator, entry: Entry) SyntaxError!void {
        const visiting = self.visited.get(entry.name);
        if (visiting) |c| {
            if (c) return; // already fully explored, safe
            return SyntaxError.CycleDetected; // back-edge = cycle
        }

        try self.visited.put(entry.name, false); // mark as visiting
        try self.visitValue(entry.value);
        try self.visited.put(entry.name, true); // mark as fully explored
    }

    fn visitIdent(self: *Validator, ident: Identifier) SyntaxError!void {
        if (self.types.get(ident)) |val| try self.visitEntry(.{
            .name = ident,
            .value = val,
        });
    }

    pub fn check(self: *Validator) SyntaxError!void {
        var iter = self.types.iterator();
        while (iter.next()) |entry| try self.visitEntry(.{
            .name = entry.key_ptr.*,
            .value = entry.value_ptr.*,
        });
    }
};

test "sanity check" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    const source = "type Foo = struct { x: Bar }; type Bar = [3] u64; event Baz = Foo;";
    const lexer = Lexer.init(source);
    var parser = Parser.init(alloc, lexer);
    const symtab = try parser.parse();
    var validator = try Validator.init(alloc, symtab);
    defer validator.deinit();
    try validator.check();
}
