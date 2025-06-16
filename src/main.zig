const std = @import("std");
const print = std.debug.print;
const parser = @import("parser.zig");
const Allocator = std.mem.Allocator;

const Emoji = parser.Emoji;
const EmojiData = parser.EmojiData;
const parseEmojiLine = parser.parseEmojiLine;

fn parseEmojiFile(allocator: Allocator, file_path: []const u8) !EmojiData {
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        print("Error opening file {s}: {}\n", .{ file_path, err });
        return err;
    };
    defer file.close();
    
    var data = EmojiData.init(allocator);
    
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    
    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
        try parseEmojiLine(allocator, line, &data);
    }
    
    return data;
}

fn writeJsonOutput(_: Allocator, data: *EmojiData, output_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    
    var writer = file.writer();
    
    try writer.writeAll("{\n  \"emojis\": [\n");
    
    for (data.emojis.items, 0..) |emoji, i| {
        try writer.writeAll("    {\n");
        try writer.print("      \"codepoint\": \"{s}\",\n", .{emoji.codepoint});
        try writer.print("      \"emoji\": \"{s}\",\n", .{emoji.emoji});
        try writer.print("      \"version\": \"{s}\",\n", .{emoji.version});
        try writer.print("      \"description\": \"{s}\",\n", .{emoji.description});
        try writer.print("      \"group\": \"{s}\",\n", .{emoji.group});
        try writer.print("      \"subgroup\": \"{s}\"\n", .{emoji.subgroup});
        
        if (i == data.emojis.items.len - 1) {
            try writer.writeAll("    }\n");
        } else {
            try writer.writeAll("    },\n");
        }
    }
    
    try writer.writeAll("  ]\n}\n");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        print("Usage: convert-txt <emoji.txt>\n", .{});
        print("Output will be written to emoji.json\n", .{});
        return;
    }
    
    const input_file = args[1];
    const output_file = "emoji.json";
    
    print("Converting {s} to {s}...\n", .{ input_file, output_file });
    
    var emoji_data = parseEmojiFile(allocator, input_file) catch |err| {
        print("Failed to parse emoji file: {}\n", .{err});
        return;
    };
    defer emoji_data.deinit();
    
    writeJsonOutput(allocator, &emoji_data, output_file) catch |err| {
        print("Failed to write JSON output: {}\n", .{err});
        return;
    };
    
    print("Successfully converted {} emojis to {s}\n", .{ emoji_data.emojis.items.len, output_file });
}

