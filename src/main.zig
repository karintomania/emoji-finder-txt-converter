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

    // iterate emojiParser.map
    var iterator = emojiParser.map.iterator();
    while (iterator.next()) |entry| {
        const emoji = entry.value_ptr.*;
        print("Emoji: {s}, Group: {s}, Subgroup: {s}, Description: {s}\n", .{ emoji.emoji, emoji.group, emoji.subgroup, emoji.desc });
    }
}
