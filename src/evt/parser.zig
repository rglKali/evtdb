const std = @import("std");
const mem = std.mem;

const Lexer = @import("lexer.zig");

pub const ArrayDecl = struct {
    size: usize, // size of the array
    type: TypeVal, // the underlying value
};

pub const FieldDecl = struct {
    name: []const u8, // field name
    typ: TypeVal, // field value
};

pub const TypeVal = union(enum) {
    Type: []const u8, // just for type aliases, like u64 or some custom MyType
    Array: ArrayDecl, // for arrays of types, like [42]u64 or some custom [42]MyType
    Struct: []FieldDecl, // for structs, like { age: u64, meta: [42]MyType }
};

// we can reuse FieldDecl, the interfaces are the same
pub const TypeDecl = FieldDecl;

pub const Symtab = struct {
    event: []const u8, // the exported event
    types: []TypeDecl, // custom types
};

pub fn parse(alloc: mem.Allocator, lexer: Lexer) !Symtab {
    _ = alloc;
    _ = lexer;
    return error.NotImplemented;
}
