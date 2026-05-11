const std = @import("std");

// The string identifier for type names and struct field names
pub const Identifier = []const u8;

// Fixed-size array
pub const Array = struct {
    size: u64,
    value: Identifier,
};

// Key-value pair for struct or unions
pub const Entry = struct {
    key: Identifier,
    value: Identifier,
};

// The value of a type definition
pub const Value = union(enum) {
    Struct: []Entry,
    Union: []Entry,
    Enum: []Identifier,
    Ident: Identifier,
    Array: Array,
};

// A type definition
pub const Type = struct {
    name: Identifier,
    typ: Value,
};

// The error type for parsing and printing
pub const Error = error{ OutOfMemory, SyntaxError };

// The main parser and printer function types
const Parser = fn (std.mem.Allocator, []const u8) Error!?[]Type;
const Printer = fn (std.mem.Allocator, []Type) Error!?[]const u8;
