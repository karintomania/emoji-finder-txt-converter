const std = @import("std");
const print = std.debug.print;
const parser = @import("parser.zig");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file_path = "emoji.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    const reader = file.reader();

    var buf_reader = std.io.bufferedReader(reader);
    const in_stream = buf_reader.reader();

    var buffer: [1024]u8 = undefined;

    var emojiParser = parser.EmojiParser.init(allocator);
    defer emojiParser.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        try emojiParser.handleLine(line);
    }

    const test_file = try std.fs.cwd().openFile("test.txt", std.fs.File.OpenFlags{ .mode = std.fs.File.OpenMode.write_only });
    // const test_file = try std.fs.cwd().openFile("test.txt", .{});

    const writer = test_file.writer();

    // iterate emojiParser.map
    var iterator = emojiParser.map.iterator();
    while (iterator.next()) |entry| {
        const emoji = entry.value_ptr.*;
        try writer.print("Emoji: {any}\n", .{emoji});
    }
}
