const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub const EmojiKeywordsPair = struct {
    emoji: []const u8,
    keywords: [][]const u8,
    arena: std.heap.ArenaAllocator,

    pub fn initFromLine(line: []const u8, allocator: Allocator) !EmojiKeywordsPair {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const arena_allocator = arena.allocator();

        var tab_split = std.mem.splitSequence(u8, line , "\t");

        const emoji = tab_split.next() orelse @panic("emoji expected");

        _ = tab_split.next(); // skip the description

        var keywords_list = std.ArrayList([]const u8).init(arena_allocator);

        const keywords_str = tab_split.next() orelse @panic("keywords expected");

        var keywords_split = std.mem.splitSequence(u8, keywords_str, ",");

        while (keywords_split.next()) |keyword| {
            try keywords_list.append(keyword);
        }

        const emojiKeywords = EmojiKeywordsPair{
            .emoji=emoji,
            .keywords=try keywords_list.toOwnedSlice(),
            .arena = arena,
        };

        keywords_list.deinit();
        return emojiKeywords;
    }

    pub fn deinit(self: EmojiKeywordsPair) void {
        self.arena.deinit();
    }
};


test "process adds keywords to emoji" {
    const line = "😀\tgrinning face\tgrinning,smile,happy,joy";
    const allocator = testing.allocator;

    const result = try EmojiKeywordsPair.initFromLine(line, allocator);
    defer result.deinit();

    try testing.expectEqual(4, result.keywords.len);
    try testing.expectEqualStrings("grinning", result.keywords[0]);
    try testing.expectEqualStrings("smile", result.keywords[1]);
    try testing.expectEqualStrings("happy", result.keywords[2]);
    try testing.expectEqualStrings("joy", result.keywords[3]);
}
