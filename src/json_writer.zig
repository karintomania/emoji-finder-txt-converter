const std = @import("std");
const print = std.debug.print;
const File = std.fs.File;
const Writer = File.Writer;

const parser = @import("parser2.zig");
const Emoji = parser.Emoji;

pub fn writeEmojisToTsv(emojis: []const Emoji, writer: Writer) !void {
    for (emojis) |emoji| {
        try writeEmojiToTsv(emoji, writer);
    }
}

pub fn writeEmojiToTsv(emoji: Emoji, writer: Writer) !void {
    // emoji\tgroup\tsubgroup\tdesc\tkeywords
    try writer.print("{s}\t{s}\t{s}\t{s}\t{s}\n", .{
        emoji.emoji,
        emoji.group,
        emoji.subgroup,
        emoji.desc,
        emoji.keywords[0],
    });
}

test "writeEmojisToTsv" {
    const emoji1 = Emoji{
        .emoji = "😀",
        .group = "Smileys & Emotion",
        .subgroup = "face-smiling",
        .desc = "grinning face",
        .keywords = &.{ "happy", "joy", "smile" },
    };

    const emoji2 = Emoji{
        .emoji = "😊",
        .group = "Smileys & Emotion",
        .subgroup = "face-smiling",
        .desc = "smiling face with smiling eyes",
        .keywords = &.{ "happy", "joy", "smile" },
    };

    const emojis: []const Emoji = &.{ emoji1, emoji2 };

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create the file using the dir
    const file = try tmp_dir.dir.createFile("emoji.tsv", File.CreateFlags{ .read = true, .mode = 777 });
    defer file.close();

    const writer = file.writer();

    try writeEmojisToTsv(emojis, writer);

    // Reset file pointer to beginning for reading
    try file.seekTo(0);

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    // Read and verify the file content line by line
    var result: [512]u8 = undefined;

    // First line assertion
    const line1 = try in_stream.readUntilDelimiterOrEof(&result, '\n');
    try std.testing.expectEqualStrings("😀\tSmileys & Emotion\tface-smiling\tgrinning face\thappy", line1.?);

    // Second line assertion
    const line2 = try in_stream.readUntilDelimiterOrEof(&result, '\n');
    try std.testing.expectEqualStrings("😊\tSmileys & Emotion\tface-smiling\tsmiling face with smiling eyes\thappy", line2.?);

    // Ensure no more lines
    const line3 = try in_stream.readUntilDelimiterOrEof(&result, '\n');
    try std.testing.expect(line3 == null);
}
