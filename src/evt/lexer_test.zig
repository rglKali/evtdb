const std = @import("std");
const meta = std.meta;
const testing = std.testing;
const Lexer = @import("lexer.zig");

// ============================================================================
// Keyword Token Tests
// ============================================================================

test "EventKeyword token" {
    var lexer = Lexer.init("event");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .EventKeyword);

    const end = try lexer.next();
    try testing.expectEqual(@as(?Lexer.Token, null), end);
}

test "TypeKeyword token" {
    var lexer = Lexer.init("type");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .TypeKeyword);

    const end = try lexer.next();
    try testing.expectEqual(@as(?Lexer.Token, null), end);
}

test "StructKeyword token" {
    var lexer = Lexer.init("struct");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .StructKeyword);

    const end = try lexer.next();
    try testing.expectEqual(@as(?Lexer.Token, null), end);
}

// ============================================================================
// Identifier Token Tests
// ============================================================================

test "Simple identifier" {
    var lexer = Lexer.init("myIdentifier");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Identifier);
    try testing.expectEqualSlices(u8, "myIdentifier", token.Identifier);

    const end = try lexer.next();
    try testing.expectEqual(@as(?Lexer.Token, null), end);
}

test "Single letter identifier" {
    var lexer = Lexer.init("x");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Identifier);
    try testing.expectEqualSlices(u8, "x", token.Identifier);
}

test "Identifier with underscores" {
    var lexer = Lexer.init("my_identifier_name");

    const token = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "my_identifier_name", token.Identifier);
}

test "Identifier with numbers" {
    var lexer = Lexer.init("identifier123");

    const token = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "identifier123", token.Identifier);
}

test "Multiple identifiers separated by whitespace" {
    var lexer = Lexer.init("first second third");

    const token1 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "first", token1.Identifier);

    const token2 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "second", token2.Identifier);

    const token3 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "third", token3.Identifier);
}

// ============================================================================
// Length/Number Token Tests
// ============================================================================

test "Single digit length" {
    var lexer = Lexer.init("5");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Length);
    try testing.expectEqual(@as(usize, 5), token.Length);
}

test "Multi-digit length" {
    var lexer = Lexer.init("12345");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Length);
    try testing.expectEqual(@as(usize, 12345), token.Length);
}

test "Zero length" {
    var lexer = Lexer.init("0");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Length);
    try testing.expectEqual(@as(usize, 0), token.Length);
}

test "Multiple lengths separated by whitespace" {
    var lexer = Lexer.init("32 64 128");

    const token1 = (try lexer.next()).?;
    try testing.expectEqual(@as(usize, 32), token1.Length);

    const token2 = (try lexer.next()).?;
    try testing.expectEqual(@as(usize, 64), token2.Length);

    const token3 = (try lexer.next()).?;
    try testing.expectEqual(@as(usize, 128), token3.Length);
}

// ============================================================================
// Punctuation/Symbol Token Tests
// ============================================================================

test "OpenBrace token" {
    var lexer = Lexer.init("{");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .OpenBrace);
}

test "CloseBrace token" {
    var lexer = Lexer.init("}");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .CloseBrace);
}

test "OpenParen token" {
    var lexer = Lexer.init("(");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .OpenParen);
}

test "CloseParen token" {
    var lexer = Lexer.init(")");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .CloseParen);
}

test "Equal token" {
    var lexer = Lexer.init("=");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Equal);
}

test "Colon token" {
    var lexer = Lexer.init(":");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Colon);
}

test "Semicolon token" {
    var lexer = Lexer.init(";");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Semicolon);
}

test "Comma token" {
    var lexer = Lexer.init(",");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Comma);
}

test "All punctuation tokens in sequence" {
    var lexer = Lexer.init("{}()=:;,");

    const brace1 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(brace1) == .OpenBrace);

    const brace2 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(brace2) == .CloseBrace);

    const paren1 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(paren1) == .OpenParen);

    const paren2 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(paren2) == .CloseParen);

    const eq = (try lexer.next()).?;
    try testing.expect(meta.activeTag(eq) == .Equal);

    const colon = (try lexer.next()).?;
    try testing.expect(meta.activeTag(colon) == .Colon);

    const semi = (try lexer.next()).?;
    try testing.expect(meta.activeTag(semi) == .Semicolon);

    const comma = (try lexer.next()).?;
    try testing.expect(meta.activeTag(comma) == .Comma);
}

// ============================================================================
// Whitespace Handling Tests
// ============================================================================

test "Whitespace is skipped" {
    var lexer = Lexer.init("  hello  world  ");

    const token1 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token1.Identifier);

    const token2 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "world", token2.Identifier);

    const end = try lexer.next();
    try testing.expectEqual(@as(?Lexer.Token, null), end);
}

test "Tabs are skipped" {
    var lexer = Lexer.init("hello\t\tworld");

    const token1 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token1.Identifier);

    const token2 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "world", token2.Identifier);
}

test "Newlines are skipped" {
    var lexer = Lexer.init("hello\nworld");

    const token1 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token1.Identifier);

    const token2 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "world", token2.Identifier);
}

test "Mixed whitespace is skipped" {
    var lexer = Lexer.init("hello \t\n\r world");

    const token1 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token1.Identifier);

    const token2 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "world", token2.Identifier);
}

// ============================================================================
// Complex Pattern Tests
// ============================================================================

test "Struct declaration pattern" {
    var lexer = Lexer.init("struct Event { field1: 32, field2: 64 }");

    const keyword = (try lexer.next()).?;
    try testing.expect(meta.activeTag(keyword) == .StructKeyword);

    const name = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "Event", name.Identifier);

    const brace1 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(brace1) == .OpenBrace);

    const field1 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "field1", field1.Identifier);

    const colon1 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(colon1) == .Colon);

    const len1 = (try lexer.next()).?;
    try testing.expectEqual(@as(usize, 32), len1.Length);

    const comma = (try lexer.next()).?;
    try testing.expect(meta.activeTag(comma) == .Comma);

    const field2 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "field2", field2.Identifier);

    const colon2 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(colon2) == .Colon);

    const len2 = (try lexer.next()).?;
    try testing.expectEqual(@as(usize, 64), len2.Length);

    const brace2 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(brace2) == .CloseBrace);
}

test "Event declaration pattern" {
    var lexer = Lexer.init("event MyEvent { timestamp: 64 }");

    const keyword = (try lexer.next()).?;
    try testing.expect(meta.activeTag(keyword) == .EventKeyword);

    const name = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "MyEvent", name.Identifier);

    const brace1 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(brace1) == .OpenBrace);

    const field = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "timestamp", field.Identifier);
}

test "Type declaration pattern" {
    var lexer = Lexer.init("type Size = 64;");

    const keyword = (try lexer.next()).?;
    try testing.expect(meta.activeTag(keyword) == .TypeKeyword);

    const name = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "Size", name.Identifier);

    const eq = (try lexer.next()).?;
    try testing.expect(meta.activeTag(eq) == .Equal);

    const length = (try lexer.next()).?;
    try testing.expectEqual(@as(usize, 64), length.Length);

    const semi = (try lexer.next()).?;
    try testing.expect(meta.activeTag(semi) == .Semicolon);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "Empty input returns null" {
    var lexer = Lexer.init("");

    const token = try lexer.next();
    try testing.expectEqual(@as(?Lexer.Token, null), token);
}

test "Only whitespace returns null" {
    var lexer = Lexer.init("   \n\t\r   ");

    const token = try lexer.next();
    try testing.expectEqual(@as(?Lexer.Token, null), token);
}

test "Identifier not confused with keywords" {
    var lexer = Lexer.init("typeX eventA structB");

    const token1 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "typeX", token1.Identifier);

    const token2 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "eventA", token2.Identifier);

    const token3 = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "structB", token3.Identifier);
}

test "Complex nested structure" {
    var lexer = Lexer.init("struct Data { inner(x: 32) = y; }");

    const kw = (try lexer.next()).?;
    try testing.expect(meta.activeTag(kw) == .StructKeyword);

    const name = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "Data", name.Identifier);

    const b1 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(b1) == .OpenBrace);

    const inner = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "inner", inner.Identifier);

    const p1 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(p1) == .OpenParen);

    const xid = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "x", xid.Identifier);

    const colon = (try lexer.next()).?;
    try testing.expect(meta.activeTag(colon) == .Colon);

    const num = (try lexer.next()).?;
    try testing.expectEqual(@as(usize, 32), num.Length);

    const p2 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(p2) == .CloseParen);
}

// ============================================================================
// Keyword Boundary Tests
// ============================================================================

test "Keywords at word boundaries only" {
    var lexer = Lexer.init("event_handler");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Identifier);
    try testing.expectEqualSlices(u8, "event_handler", token.Identifier);
}

test "Keywords case-sensitive" {
    var lexer = Lexer.init("EVENT Type STRUCT");

    const t1 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(t1) == .Identifier);

    const t2 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(t2) == .Identifier);

    const t3 = (try lexer.next()).?;
    try testing.expect(meta.activeTag(t3) == .Identifier);
}

// ============================================================================
// Large Numbers and Identifiers
// ============================================================================

test "Very large number" {
    var lexer = Lexer.init("18446744073709551615");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Length);
}

test "Long identifier name" {
    var lexer = Lexer.init("this_is_a_very_long_identifier_name_with_many_characters");

    const token = (try lexer.next()).?;
    try testing.expect(meta.activeTag(token) == .Identifier);
    try testing.expectEqualSlices(u8, "this_is_a_very_long_identifier_name_with_many_characters", token.Identifier);
}

// ============================================================================
// Punctuation with Identifiers
// ============================================================================

test "Punctuation attached to identifiers are separate tokens" {
    var lexer = Lexer.init("name:value;");

    const name = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "name", name.Identifier);

    const colon = (try lexer.next()).?;
    try testing.expect(meta.activeTag(colon) == .Colon);

    const value = (try lexer.next()).?;
    try testing.expectEqualSlices(u8, "value", value.Identifier);

    const semi = (try lexer.next()).?;
    try testing.expect(meta.activeTag(semi) == .Semicolon);
}
