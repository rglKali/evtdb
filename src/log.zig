const std = @import("std");
const Io = std.Io;
const File = Io.File;
const Dir = Io.Dir;

const Log = @This();

file: File,
size: u64,
height: u64,

pub fn open(io: Io, dir: Dir, path: []const u8, comptime size: u64) !Log {
    const file = try dir.createFile(io, path, .{ .read = true, .truncate = false });
    const length = try file.length(io);
    const height = length / size;

    return .{
        .file = file,
        .size = size,
        .height = height,
    };
}

pub fn close(self: *Log, io: Io) void {
    self.file.close(io);
}

pub fn append(self: *Log, io: Io, entry: []const u8) !void {
    if (entry.len != self.size) return error.InvalidEntrySize;
    try self.file.writePositionalAll(io, entry, self.size * self.height);
    try self.file.sync(io);
    self.height += 1;
}

pub fn read(self: *Log, io: Io, idx: usize, to: []u8) !void {
    if (to.len != self.size) return error.InvalidEntrySize;
    if (idx >= self.height) return error.EndOfStream;
    _ = try self.file.readPositionalAll(io, to, idx * self.size);
}

const testing = std.testing;

test "open creates an empty log with height 0" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try Log.open(io, tmp.dir, "log.bin", 8);
    defer log.close(io);

    try testing.expectEqual(@as(usize, 0), log.height);
}

test "append one entry then read it back" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try Log.open(io, tmp.dir, "log.bin", 8);
    defer log.close(io);

    const entry: []const u8 = "abcdefgh";
    try log.append(io, entry);
    try testing.expectEqual(@as(usize, 1), log.height);

    var out: [8]u8 = undefined;
    try log.read(io, 0, &out);
    try testing.expectEqualSlices(u8, entry, &out);
}

test "append many entries and read each by index" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try Log.open(io, tmp.dir, "log.bin", 4);
    defer log.close(io);

    const entries = [_][]const u8{
        "aaaa",
        "bbbb",
        "cccc",
        "dddd",
    };
    for (entries) |e| try log.append(io, e);

    try testing.expectEqual(@as(usize, entries.len), log.height);

    var out: [4]u8 = undefined;
    for (entries, 0..) |expected, i| {
        try log.read(io, i, &out);
        try testing.expectEqualSlices(u8, expected, &out);
    }
}

test "reopen recovers height and contents from disk" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const e0: []const u8 = "01234567";
    const e1: []const u8 = "89abcdef";

    {
        var log = try Log.open(io, tmp.dir, "log.bin", 8);
        defer log.close(io);
        try log.append(io, e0);
        try log.append(io, e1);
    }

    var log = try Log.open(io, tmp.dir, "log.bin", 8);
    defer log.close(io);

    try testing.expectEqual(@as(usize, 2), log.height);

    var out: [8]u8 = undefined;
    try log.read(io, 0, &out);
    try testing.expectEqualSlices(u8, e0, &out);
    try log.read(io, 1, &out);
    try testing.expectEqualSlices(u8, e1, &out);
}

test "append after reopen continues from previous height" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const e0: []const u8 = "aaaa";
    const e1: []const u8 = "bbbb";

    {
        var log = try Log.open(io, tmp.dir, "log.bin", 4);
        defer log.close(io);
        try log.append(io, e0);
    }

    var log = try Log.open(io, tmp.dir, "log.bin", 4);
    defer log.close(io);
    try testing.expectEqual(@as(usize, 1), log.height);

    try log.append(io, e1);
    try testing.expectEqual(@as(usize, 2), log.height);

    var out: [4]u8 = undefined;
    try log.read(io, 0, &out);
    try testing.expectEqualSlices(u8, e0, &out);
    try log.read(io, 1, &out);
    try testing.expectEqualSlices(u8, e1, &out);
}

test "open fails when parent directory does not exist" {
    const io = testing.io;

    const result = Log.open(io, Dir.cwd(), "evtdb-nonexistent-parent/log.bin", 8);
    try testing.expectError(error.FileNotFound, result);
}

test "trailing partial entry is excluded from height on open" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // 1 full 8-byte entry plus 5 trailing bytes of an incomplete one.
    {
        const f = try tmp.dir.createFile(io, "log.bin", .{ .truncate = true });
        defer f.close(io);
        try f.writePositionalAll(io, "ABCDEFGH12345", 0);
        try f.sync(io);
    }

    var log = try Log.open(io, tmp.dir, "log.bin", 8);
    defer log.close(io);

    try testing.expectEqual(@as(usize, 1), log.height);

    var out: [8]u8 = undefined;
    try log.read(io, 0, &out);
    try testing.expectEqualSlices(u8, "ABCDEFGH", &out);
}

test "open is idempotent on an existing complete log" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var log = try Log.open(io, tmp.dir, "log.bin", 4);
        defer log.close(io);
        try log.append(io, "wxyz");
    }

    {
        var log = try Log.open(io, tmp.dir, "log.bin", 4);
        defer log.close(io);
        try testing.expectEqual(@as(usize, 1), log.height);
    }

    var log = try Log.open(io, tmp.dir, "log.bin", 4);
    defer log.close(io);
    try testing.expectEqual(@as(usize, 1), log.height);
}

test "append rejects entry with wrong size" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try Log.open(io, tmp.dir, "log.bin", 4);
    defer log.close(io);

    try testing.expectError(error.InvalidEntrySize, log.append(io, "abc"));
    try testing.expectError(error.InvalidEntrySize, log.append(io, "abcde"));
    try testing.expectEqual(@as(usize, 0), log.height);
}

test "read past the end returns EndOfStream" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try Log.open(io, tmp.dir, "log.bin", 4);
    defer log.close(io);

    var out: [4]u8 = undefined;
    try testing.expectError(error.EndOfStream, log.read(io, 0, &out));

    try log.append(io, "aaaa");
    try testing.expectError(error.EndOfStream, log.read(io, 1, &out));
}
