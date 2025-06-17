const std = @import("std");
const print = std.debug.print;
const parser = @import("parser.zig");
const Allocator = std.mem.Allocator;


pub fn main() !void {
    // const gpa = std.heap.GeneralPurposeAllocator(.{});
    // const allocator = gpa.allocator();

    const file_path = "emoji.txt";

    const file = try std.fs.cwd().openFile(file_path, .{});
    const reader = file.reader();

    var buf_reader = std.io.bufferedReader(reader);
    const in_stream = buf_reader.reader();

    var group: []const u8 = undefined;
    var subgroup: []const u8 = undefined;
    var emoji: parser.Emoji = undefined;

    var buffer: [1024]u8 = undefined;

    while(try in_stream.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
        const line_type = parser.getLineType(line);

        switch (line_type) {
            .emoji => {
                emoji = parser.parseEmojiLine(group, subgroup, line);
                print("Emoji: {s}, Group: {s}, Subgroup: {s}, Desc: {s}\n",
                    .{emoji.emoji, emoji.group, emoji.subgroup, emoji.desc});
            },
            .group => {
                group = parser.parseGroupLine(line);
                print("Group: {s}\n", .{group});
            },
            .subgroup => {
                subgroup = parser.parseGroupLine(line);
                print("Subgroup: {s}\n", .{subgroup});
            },
            else => {},
        }
    }
}
