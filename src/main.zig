const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Emoji = struct {
    codepoint: []const u8,
    emoji: []const u8,
    version: []const u8,
    description: []const u8,
    group: []const u8,
    subgroup: []const u8,
};

const EmojiData = struct {
    emojis: ArrayList(Emoji),
    current_group: []const u8,
    current_subgroup: []const u8,
    allocator: Allocator,

    fn init(allocator: Allocator) EmojiData {
        return EmojiData{
            .emojis = ArrayList(Emoji).init(allocator),
            .current_group = "",
            .current_subgroup = "",
            .allocator = allocator,
        };
    }

    fn deinit(self: *EmojiData) void {
        for (self.emojis.items) |emoji| {
            self.allocator.free(emoji.codepoint);
            self.allocator.free(emoji.emoji);
            self.allocator.free(emoji.version);
            self.allocator.free(emoji.description);
            self.allocator.free(emoji.group);
            self.allocator.free(emoji.subgroup);
        }
        self.emojis.deinit();
    }
};

fn parseEmojiLine(allocator: Allocator, line: []const u8, data: *EmojiData) !void {
    if (line.len == 0 or line[0] == '\n') return;
    
    if (std.mem.startsWith(u8, line, "# group: ")) {
        const group_name = std.mem.trim(u8, line[9..], " \t\n\r");
        data.current_group = try allocator.dupe(u8, group_name);
        return;
    }
    
    if (std.mem.startsWith(u8, line, "# subgroup: ")) {
        const subgroup_name = std.mem.trim(u8, line[12..], " \t\n\r");
        data.current_subgroup = try allocator.dupe(u8, subgroup_name);
        return;
    }
    
    if (line[0] == '#') return;
    
    var parts = std.mem.split(u8, line, ";");
    const codepoint_part = std.mem.trim(u8, parts.next() orelse return, " \t");
    const rest = std.mem.trim(u8, parts.next() orelse return, " \t");
    
    var comment_parts = std.mem.split(u8, rest, "#");
    _ = comment_parts.next();
    const comment = std.mem.trim(u8, comment_parts.next() orelse return, " \t\n\r");
    
    var comment_split = std.mem.split(u8, comment, " ");
    const emoji_char = comment_split.next() orelse return;
    const version_part = comment_split.next() orelse return;
    
    const description_start = std.mem.indexOf(u8, comment, version_part) orelse return;
    const description = std.mem.trim(u8, comment[description_start + version_part.len..], " \t\n\r");
    
    const emoji = Emoji{
        .codepoint = try allocator.dupe(u8, codepoint_part),
        .emoji = try allocator.dupe(u8, emoji_char),
        .version = try allocator.dupe(u8, version_part),
        .description = try allocator.dupe(u8, description),
        .group = try allocator.dupe(u8, data.current_group),
        .subgroup = try allocator.dupe(u8, data.current_subgroup),
    };
    
    try data.emojis.append(emoji);
}

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

fn writeJsonOutput(allocator: Allocator, data: *EmojiData, output_path: []const u8) !void {
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
        print("Usage: convert-txt <emoji.txt>\n");
        print("Output will be written to emoji.json\n");
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