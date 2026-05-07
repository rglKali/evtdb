const std = @import("std");

// The string identifier for type names and struct field names
pub const Identifier = []const u8;

pub fn freeIdentifier(alloc: std.mem.Allocator, id: Identifier) void {
    alloc.free(id);
}

pub fn freeIdentifiers(alloc: std.mem.Allocator, idents: []Identifier) void {
    for (idents) |ident| freeIdentifier(alloc, ident);
    alloc.free(idents);
}

// Fixed-size array
pub const Array = struct {
    size: u64,
    value: Type,
};

pub fn freeArray(alloc: std.mem.Allocator, array: *Array) void {
    freeType(alloc, array.value);
    alloc.destroy(array);
}

// Key-value pair for identifier and the type it maps to
pub const Entry = struct {
    key: Identifier,
    value: Type,
};

pub fn freeEntry(alloc: std.mem.Allocator, e: Entry) void {
    freeIdentifier(alloc, e.key);
    freeType(alloc, e.value);
}

pub fn freeEntries(alloc: std.mem.Allocator, entries: []Entry) void {
    for (entries) |entry| freeEntry(alloc, entry);
    alloc.free(entries);
}

// The different types that can be defined in the schema
pub const Type = union(enum) {
    Struct: []Entry,
    Union: []Entry,
    Enum: []Identifier,
    Ident: Identifier,
    Array: *Array, // to avoid recursive type definition
};

pub fn freeType(alloc: std.mem.Allocator, value: Type) void {
    switch (value) {
        .Struct, .Union => |fields| freeEntries(alloc, fields),
        .Enum => |idents| freeIdentifiers(alloc, idents),
        .Ident => |ident| freeIdentifier(alloc, ident),
        .Array => |arr| freeArray(alloc, arr),
    }
}

pub fn free(alloc: std.mem.Allocator, entries: []Entry) void {
    freeEntries(alloc, entries);
}

pub const Error = error{ OutOfMemory, SyntaxError };

const Parser = fn (std.mem.Allocator, []const u8) Error!?[]Entry;
const Printer = fn (std.mem.Allocator, []Entry) Error!?[]const u8;
