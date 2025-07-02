const std = @import("std");
const print = std.debug.print;
const parser = @import("parser.zig");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var emojiParser = parser.EmojiParser.init(allocator);
    defer emojiParser.deinit();

    try readEmojiFile(&emojiParser);

    try readKeywordsFile(&emojiParser);

    const result_file = try std.fs.cwd().openFile("result.tsv", std.fs.File.OpenFlags{ .mode = std.fs.File.OpenMode.write_only });

    const writer = result_file.writer();

    // iterate emojiParser.map
    var iterator = emojiParser.map.iterator();
    while (iterator.next()) |entry| {
        const emoji = entry.value_ptr.*;
        try writer.print("Emoji: {any}\n", .{emoji});
    }
}

fn readEmojiFile(emojiParser: *parser.EmojiParser) !void {
    const emoji_file_path = "emoji.txt";

    const emoji_file = try std.fs.cwd().openFile(emoji_file_path, .{});
    const reader = emoji_file.reader();

    var buf_reader = std.io.bufferedReader(reader);
    const in_stream = buf_reader.reader();

    var buffer: [1024]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        try emojiParser.handleEmojiLine(line);
    }
}

fn readKeywordsFile(emojiParser: *parser.EmojiParser) !void {
    const keywords_file_path = "keywords.tsv";

    const keywords_file = try std.fs.cwd().openFile(keywords_file_path, .{});
    const reader = keywords_file.reader();

    var buf_reader = std.io.bufferedReader(reader);
    const in_stream = buf_reader.reader();

    var buffer: [1024]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        try emojiParser.handleKeywordsLine(line);
    }
}
