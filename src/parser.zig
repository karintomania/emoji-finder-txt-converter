const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Emoji = struct {
    codepoint: []const u8,
    emoji: []const u8,
    version: []const u8,
    description: []const u8,
    group: []const u8,
    subgroup: []const u8,
};

pub const EmojiData = struct {
    emojis: ArrayList(Emoji),
    current_group: []const u8,
    current_subgroup: []const u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator) EmojiData {
        return EmojiData{
            .emojis = ArrayList(Emoji).init(allocator),
            .current_group = "",
            .current_subgroup = "",
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EmojiData) void {
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

pub fn parseEmojiLine(allocator: Allocator, line: []const u8, data: *EmojiData) !void {
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
    
    var parts = std.mem.splitScalar(u8, line, ';');
    const codepoint_part = std.mem.trim(u8, parts.next() orelse return, " \t");
    const rest = std.mem.trim(u8, parts.next() orelse return, " \t");
    
    var comment_parts = std.mem.splitScalar(u8, rest, '#');
    _ = comment_parts.next();
    const comment = std.mem.trim(u8, comment_parts.next() orelse return, " \t\n\r");
    
    var comment_split = std.mem.splitScalar(u8, comment, ' ');
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

test "parseEmojiLine - basic emoji parsing" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var data = EmojiData.init(allocator);
    defer data.deinit();
    
    // Set up group and subgroup context
    data.current_group = try allocator.dupe(u8, "Smileys & Emotion");
    data.current_subgroup = try allocator.dupe(u8, "face-smiling");
    
    // Test parsing a basic emoji line
    const line = "1F600          ; fully-qualified     # 😀 E1.0 grinning face";
    try parseEmojiLine(allocator, line, &data);
    
    try testing.expect(data.emojis.items.len == 1);
    try testing.expectEqualStrings("1F600", data.emojis.items[0].codepoint);
    try testing.expectEqualStrings("😀", data.emojis.items[0].emoji);
    try testing.expectEqualStrings("E1.0", data.emojis.items[0].version);
    try testing.expectEqualStrings("grinning face", data.emojis.items[0].description);
    try testing.expectEqualStrings("Smileys & Emotion", data.emojis.items[0].group);
    try testing.expectEqualStrings("face-smiling", data.emojis.items[0].subgroup);
}

test "parseEmojiLine - group and subgroup parsing" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var data = EmojiData.init(allocator);
    defer data.deinit();
    
    // Test group parsing
    const group_line = "# group: Smileys & Emotion";
    try parseEmojiLine(allocator, group_line, &data);
    try testing.expectEqualStrings("Smileys & Emotion", data.current_group);
    
    // Test subgroup parsing
    const subgroup_line = "# subgroup: face-smiling";
    try parseEmojiLine(allocator, subgroup_line, &data);
    try testing.expectEqualStrings("face-smiling", data.current_subgroup);
}

test "parseEmojiLine - skip empty lines and comments" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var data = EmojiData.init(allocator);
    defer data.deinit();
    
    // Test empty line
    try parseEmojiLine(allocator, "", &data);
    try testing.expect(data.emojis.items.len == 0);
    
    // Test comment line
    try parseEmojiLine(allocator, "# This is a comment", &data);
    try testing.expect(data.emojis.items.len == 0);
    
    // Test newline only
    try parseEmojiLine(allocator, "\n", &data);
    try testing.expect(data.emojis.items.len == 0);
}