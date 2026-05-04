const std = @import("std");
const meta = std.meta;
const testing = std.testing;
const Scanner = @import("scanner.zig");

// ============================================================================
// Basic Single Delimiter Tests
// ============================================================================

test "Single delimiter: space" {
    var tokenizer = Scanner.init("hello world", " ");

    const token1 = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(token1) == .blob);
    try testing.expectEqualSlices(u8, "hello", token1.blob);

    const delim = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(delim) == .symbol);
    try testing.expectEqual(@as(u8, ' '), delim.symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(token2) == .blob);
    try testing.expectEqualSlices(u8, "world", token2.blob);

    const end = try tokenizer.next();
    try testing.expectEqual(@as(?Scanner.BlobOrSymbol, null), end);
}

test "Single delimiter: comma" {
    var tokenizer = Scanner.init("a,b,c", ",");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "a", token1.blob);

    const delim1 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim1.symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "b", token2.blob);

    const delim2 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim2.symbol);

    const token3 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "c", token3.blob);
}

test "Single delimiter: colon" {
    var tokenizer = Scanner.init("key:value", ":");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "key", token1.blob);

    const delim = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ':'), delim.symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "value", token2.blob);
}

// ============================================================================
// Multiple Delimiter Tests
// ============================================================================

test "Multiple delimiters: space and comma" {
    var tokenizer = Scanner.init("hello, world", " ,");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token1.blob);

    const delim1 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim1.symbol);

    const delim2 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ' '), delim2.symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "world", token2.blob);
}

test "Multiple delimiters: various punctuation" {
    var tokenizer = Scanner.init("a-b_c", "-_");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "a", token1.blob);

    const delim1 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, '-'), delim1.symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "b", token2.blob);

    const delim2 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, '_'), delim2.symbol);

    const token3 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "c", token3.blob);
}

// ============================================================================
// Empty and Edge Case Tests
// ============================================================================

test "Empty string" {
    var tokenizer = Scanner.init("", ",");

    const result = try tokenizer.next();
    try testing.expectEqual(@as(?Scanner.BlobOrSymbol, null), result);
}

test "Only delimiter" {
    var tokenizer = Scanner.init(",", ",");

    const delim = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim.symbol);

    const end = try tokenizer.next();
    try testing.expectEqual(@as(?Scanner.BlobOrSymbol, null), end);
}

test "Multiple consecutive delimiters" {
    var tokenizer = Scanner.init("a,,,b", ",");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "a", token1.blob);

    const delim1 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim1.symbol);

    const delim2 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim2.symbol);

    const delim3 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim3.symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "b", token2.blob);
}

test "Delimiter at start" {
    var tokenizer = Scanner.init(",hello", ",");

    const delim = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim.symbol);

    const token = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token.blob);
}

test "Delimiter at end" {
    var tokenizer = Scanner.init("hello,", ",");

    const token = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token.blob);

    const delim = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim.symbol);
}

test "No delimiters in stream" {
    var tokenizer = Scanner.init("hello", ",");

    const token = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token.blob);

    const end = try tokenizer.next();
    try testing.expectEqual(@as(?Scanner.BlobOrSymbol, null), end);
}

// ============================================================================
// Complex Patterns
// ============================================================================

test "CSV-like pattern" {
    var tokenizer = Scanner.init("name,age,city", ",");

    const field1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "name", field1.blob);

    _ = (try tokenizer.next()).?; // skip delimiter

    const field2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "age", field2.blob);

    _ = (try tokenizer.next()).?; // skip delimiter

    const field3 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "city", field3.blob);
}

test "Path-like pattern" {
    var tokenizer = Scanner.init("usr/local/bin", "/");

    const part1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "usr", part1.blob);

    _ = (try tokenizer.next()).?; // skip delimiter

    const part2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "local", part2.blob);

    _ = (try tokenizer.next()).?; // skip delimiter

    const part3 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "bin", part3.blob);
}

test "URL query string pattern" {
    var tokenizer = Scanner.init("key1=val1&key2=val2", "&");

    const param1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "key1=val1", param1.blob);

    _ = (try tokenizer.next()).?; // skip delimiter

    const param2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "key2=val2", param2.blob);
}

// ============================================================================
// Whitespace Handling
// ============================================================================

test "Space as delimiter" {
    var tokenizer = Scanner.init("a b c", " ");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "a", token1.blob);

    _ = (try tokenizer.next()).?;

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "b", token2.blob);

    _ = (try tokenizer.next()).?;

    const token3 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "c", token3.blob);
}

test "Tab as delimiter" {
    var tokenizer = Scanner.init("a\tb\tc", "\t");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "a", token1.blob);

    _ = (try tokenizer.next()).?;

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "b", token2.blob);
}

test "Multiple whitespace delimiters" {
    var tokenizer = Scanner.init("a\t b", "\t ");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "a", token1.blob);

    const delim1 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, '\t'), delim1.symbol);

    const delim2 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ' '), delim2.symbol);
    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "b", token2.blob);
}

// ============================================================================
// Position Tracking
// ============================================================================

test "Position advances correctly" {
    var tokenizer = Scanner.init("a,b", ",");
    try testing.expectEqual(@as(usize, 0), tokenizer.pos);

    _ = try tokenizer.next();
    try testing.expectEqual(@as(usize, 1), tokenizer.pos);

    _ = try tokenizer.next();
    try testing.expectEqual(@as(usize, 2), tokenizer.pos);

    _ = try tokenizer.next();
    try testing.expectEqual(@as(usize, 3), tokenizer.pos);

    _ = try tokenizer.next();
    try testing.expectEqual(@as(usize, 3), tokenizer.pos);
}

test "Multiple iterations" {
    var tokenizer = Scanner.init("one:two:three", ":");

    var count: usize = 0;
    while (try tokenizer.next() != null) {
        count += 1;
    }
    try testing.expectEqual(@as(usize, 5), count);
}

// ============================================================================
// Single Character Tokens
// ============================================================================

test "Single character tokens" {
    var tokenizer = Scanner.init("x,y,z", ",");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "x", token1.blob);

    _ = (try tokenizer.next()).?;

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "y", token2.blob);

    _ = (try tokenizer.next()).?;

    const token3 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "z", token3.blob);
}

test "Adjacent delimiters only" {
    var tokenizer = Scanner.init(",,", ",");

    const delim1 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim1.symbol);

    const delim2 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim2.symbol);

    const end = try tokenizer.next();
    try testing.expectEqual(@as(?Scanner.BlobOrSymbol, null), end);
}

// ============================================================================
// Real-world Patterns
// ============================================================================

test "Log line parsing" {
    var tokenizer = Scanner.init("ERROR|component|message|timestamp", "|");

    const level = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "ERROR", level.blob);

    _ = (try tokenizer.next()).?; // delimiter

    const component = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "component", component.blob);
}

test "Configuration key-value" {
    var tokenizer = Scanner.init("name:John Doe;age:30", ";");

    const first = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "name:John Doe", first.blob);

    _ = (try tokenizer.next()).?; // delimiter

    const second = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "age:30", second.blob);
}

test "Long text with sparse delimiters" {
    var tokenizer = Scanner.init("This is a long token,and another,and one more", ",");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "This is a long token", token1.blob);

    _ = (try tokenizer.next()).?; // delimiter

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "and another", token2.blob);

    _ = (try tokenizer.next()).?; // delimiter

    const token3 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "and one more", token3.blob);
}

// ============================================================================
// Special Characters
// ============================================================================

test "Special characters as delimiters" {
    var tokenizer = Scanner.init("hello@world#test", "@#");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "hello", token1.blob);

    const delim1 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, '@'), delim1.symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "world", token2.blob);

    const delim2 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, '#'), delim2.symbol);

    const token3 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "test", token3.blob);
}

test "Numeric content with delimiters" {
    var tokenizer = Scanner.init("123,456,789", ",");

    const num1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "123", num1.blob);

    _ = (try tokenizer.next()).?; // delimiter

    const num2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "456", num2.blob);
}

// ============================================================================
// Union Tag Checking
// ============================================================================

test "Token tag verification" {
    var tokenizer = Scanner.init("text", ",");

    const item = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(item) == .blob);
}

test "Delim tag verification" {
    var tokenizer = Scanner.init(",", ",");

    const item = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(item) == .symbol);
}

test "Alternating token and delimiter tags" {
    var tokenizer = Scanner.init("a,b", ",");

    const token1 = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(token1) == .blob);

    const delim = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(delim) == .symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(token2) == .blob);
}

// ============================================================================
// Empty Token Handling
// ============================================================================

test "Empty token between delimiters" {
    var tokenizer = Scanner.init("a,,b", ",");

    const token1 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "a", token1.blob);

    const delim1 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim1.symbol);

    const delim2 = (try tokenizer.next()).?;
    try testing.expectEqual(@as(u8, ','), delim2.symbol);

    const token2 = (try tokenizer.next()).?;
    try testing.expectEqualSlices(u8, "b", token2.blob);
}

// ============================================================================
// Text Length Tests
// ============================================================================

test "Very long token text" {
    var tokenizer = Scanner.init("this is an extremely long token that contains many characters and words,short", ",");

    const long_token = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(long_token) == .blob);
    try testing.expectEqual(@as(usize, 71), long_token.blob.len);

    const delim = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(delim) == .symbol);
    try testing.expectEqual(@as(u8, ','), delim.symbol);

    const short_token = (try tokenizer.next()).?;
    try testing.expect(meta.activeTag(short_token) == .blob);
    try testing.expectEqualSlices(u8, "short", short_token.blob);
}
