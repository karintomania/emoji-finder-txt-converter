const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// inalid line includes empty lines and non-fully-qualified emojis
const LineType = enum { group, subgroup, emoji, emoji_skin, invalid };

pub const Emoji = struct {
    emoji: []const u8,
    group: []const u8,
    subgroup: []const u8,
    desc: []const u8,
    keywords: []const []const u8,
    skin_tones: [5]ArrayList([]const u8),
};

pub const EmojiParser = struct {
    group: []const u8,
    subgroup: []const u8,
    base_emoji: Emoji, // store the base emoji for skin tones
    arena: std.heap.ArenaAllocator,
    allocator: Allocator,
    map: std.StringHashMap(Emoji),

    pub fn init(allocator: Allocator) EmojiParser {
        const arena = std.heap.ArenaAllocator.init(allocator);

        return EmojiParser{
            .group = "",
            .subgroup = "",
            .base_emoji = undefined,
            .arena = arena,
            .allocator = allocator,
            .map = std.StringHashMap(Emoji).init(allocator),
        };
    }

    pub fn handleLine(
        self: *EmojiParser,
        line: []const u8,
    ) !void {
        const arena_allocator = self.arena.allocator();
        const lineType = getLineType(line);

        switch (lineType) {
            .emoji => {
                const emoji = try parseEmojiLine(self.group, self.subgroup, line, arena_allocator);
                try self.map.put(emoji.emoji, emoji);
                self.base_emoji = emoji;
            },
            .emoji_skin => {
                try getSkinToneIndex(&self.base_emoji, line, arena_allocator);
                try self.map.put(self.base_emoji.emoji, self.base_emoji);
            },
            .group => {
                const group_slice = parseGroupLine(line);
                self.group = try arena_allocator.dupe(u8, group_slice);
            },
            .subgroup => {
                const subgroup_slice = parseGroupLine(line);
                self.subgroup = try arena_allocator.dupe(u8, subgroup_slice);
            },
            else => {},
        }
    }

    pub fn deinit(self: *EmojiParser) void {
        self.map.deinit();
        self.arena.deinit();
    }
};

fn getLineType(line: []const u8) LineType {
    if (std.mem.indexOf(u8, line, "# group") != null) {
        return LineType.group;
    } else if (std.mem.indexOf(u8, line, "# subgroup") != null) {
        return LineType.subgroup;
    } else if (std.mem.indexOf(u8, line, "fully-qualified") != null) {
        if (std.mem.indexOf(u8, line, "skin tone") != null) {
            return LineType.emoji_skin;
        } else {
            return LineType.emoji;
        }
    } else {
        return LineType.invalid;
    }
}

fn parseEmojiLine(
    group: []const u8,
    subgroup: []const u8,
    line: []const u8,
    allocator: Allocator,
) !Emoji {
    const commentIndex = std.mem.indexOf(u8, line, "#") orelse @panic("failed to parse");
    const comment = std.mem.trim(u8, line[commentIndex + 1 ..], " ");

    var commentParts = std.mem.splitSequence(u8, comment, " ");

    const emoji_slice = commentParts.next() orelse @panic("No emoji found in line");
    const emoji = try allocator.dupe(u8, emoji_slice);

    // skip version
    _ = commentParts.next();

    var descList = std.ArrayList([]const u8).init(allocator);
    defer descList.deinit();

    while (commentParts.next()) |part| {
        descList.append(part) catch @panic("Failed to append to descList");
    }

    const desc = std.mem.join(allocator, " ", descList.items) catch @panic("Failed to join desc");

    return Emoji{
        .group = group,
        .subgroup = subgroup,
        .emoji = emoji,
        .desc = desc,
        .keywords = &.{},
        .skin_tones = [5]ArrayList([]const u8){
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
            ArrayList([]const u8).init(allocator),
        },
    };
}

// index:
// 0 - light
// 1 - mid-light
// 2 - mid
// 3 - mid-dark
// 4 - dark
fn getSkinToneIndex(emoji: *Emoji, line: []const u8, allocator: Allocator) !void {
    const commentIndex = std.mem.indexOf(u8, line, "#") orelse @panic("failed to parse");
    const comment = std.mem.trim(u8, line[commentIndex + 1 ..], " ");

    var commentParts = std.mem.splitSequence(u8, comment, " ");

    const emoji_slice = commentParts.next() orelse @panic("No emoji found in line");

    const emoji_str = try allocator.dupe(u8, emoji_slice);

    if (std.mem.indexOf(u8, line, "1F3FB") != null) {
        std.debug.print("inside 1F3FB\n", .{});
        try emoji.skin_tones[0].append(emoji_str);
    }
    if (std.mem.indexOf(u8, line, "1F3FC") != null) {
        emoji.skin_tones[1].append(emoji_str) catch return;
    }
    if (std.mem.indexOf(u8, line, "1F3FD") != null) {
        emoji.skin_tones[2].append(emoji_str) catch return;
    }
    if (std.mem.indexOf(u8, line, "1F3FE") != null) {
        emoji.skin_tones[3].append(emoji_str) catch return;
    }
    if (std.mem.indexOf(u8, line, "1F3FF") != null) {
        emoji.skin_tones[4].append(emoji_str) catch return;
    }
}

fn parseGroupLine(line: []const u8) []const u8 {
    var it = std.mem.splitSequence(u8, line, ": ");
    _ = it.next();

    const result = it.next() orelse @panic("Failed to parse group line");

    return result;
}

test "EmojiParser handles lines" {
    const test_cases = [_][]const u8{
        "# group: Smileys & Emotion",
        "# subgroup: face-smiling",
        "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face",
        "1F636 200D 1F32B FE0F                                  ; fully-qualified     # 😶‍🌫️ E13.1 face in clouds",
        "1F636 200D 1F32B                                       ; minimally-qualified # 😶‍🌫 E13.1 face in clouds", // Non-fully fully-qualified Emoji will be skipped
    };

    var parser = EmojiParser.init(testing.allocator);
    defer parser.deinit();

    for (test_cases) |line| {
        try parser.handleLine(line);
    }

    try testing.expectEqual(2, parser.map.count());
    const grinning = parser.map.get("😀") orelse {
        try testing.expect(false); // Fail if emoji not found
        return;
    };
    try testing.expectEqualStrings("Smileys & Emotion", grinning.group);
    try testing.expectEqualStrings("face-smiling", grinning.subgroup);
    try testing.expectEqualStrings("😀", grinning.emoji);
    try testing.expectEqualStrings("grinning face", grinning.desc);
    try testing.expectEqual(0, grinning.keywords.len);

    const big_eye = parser.map.get("😶‍🌫️") orelse {
        try testing.expect(false); // Fail if emoji not found
        return;
    };
    try testing.expectEqualStrings("Smileys & Emotion", big_eye.group);
    try testing.expectEqualStrings("face-smiling", big_eye.subgroup);
    try testing.expectEqualStrings("😶‍🌫️", big_eye.emoji);
    try testing.expectEqualStrings("face in clouds", big_eye.desc);
    try testing.expectEqual(0, big_eye.keywords.len);
}

test "EmojiParser handles skin tones" {
    const test_cases = [_][]const u8{
        "# group: People & Body",
        "# subgroup: person-resting",
        "1F9D8                                                  ; fully-qualified     # 🧘 E5.0 person in lotus position",
        "1F9D8 1F3FB                                            ; fully-qualified     # 🧘🏻 E5.0 person in lotus position: light skin tone",
        "1F9D8 1F3FC                                            ; fully-qualified     # 🧘🏼 E5.0 person in lotus position: medium-light skin tone",
    };

    var parser = EmojiParser.init(testing.allocator);
    defer parser.deinit();

    for (test_cases) |line| {
        try parser.handleLine(line);
    }

    try testing.expectEqual(1, parser.map.count());
    const base = parser.map.get("🧘") orelse {
        try testing.expect(false); // Fail if emoji not found
        return;
    };
    try testing.expectEqualStrings("People & Body", base.group);
    try testing.expectEqualStrings("person-resting", base.subgroup);
    try testing.expectEqualStrings("🧘", base.emoji);
    try testing.expectEqualStrings("person in lotus position", base.desc);

    const light_skin = base.skin_tones[0];
    try testing.expectEqual(1, light_skin.items.len);
    try testing.expectEqualStrings("🧘🏻", light_skin.items[0]);

    const medium_light_skin = base.skin_tones[1];
    try testing.expectEqual(1, medium_light_skin.items.len);
    try testing.expectEqualStrings("🧘🏼", medium_light_skin.items[0]);
}

test "getLineType returns type" {
    const test_cases = [_]struct { expectedType: LineType, line: []const u8 }{
        .{ .expectedType = LineType.group, .line = "# group: Smileys & Emotion" },
        .{ .expectedType = LineType.subgroup, .line = "# subgroup: face-smiling" },
        .{ .expectedType = LineType.emoji, .line = "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face" },
        .{ .expectedType = LineType.emoji_skin, .line = "1F9D8 1F3FF                                            ; fully-qualified     # 🧘🏿 E5.0 person in lotus position: dark skin tone" },
        .{ .expectedType = LineType.invalid, .line = "1F636 200D 1F32B                                       ; minimally-qualified # 😶‍🌫 E13.1 face in clouds" },
    };

    for (test_cases) |test_case| {
        const result = getLineType(test_case.line);

        try testing.expectEqual(test_case.expectedType, result);
    }
}

test "parseEmojiLine returns parsed Emoji" {
    const emojiLine = "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face";

    const group = "Smileys & Emotion";
    const subgroup = "face-smiling";

    const res = try parseEmojiLine(group, subgroup, emojiLine, testing.allocator);
    defer testing.allocator.free(res.emoji);
    defer testing.allocator.free(res.desc);

    try testing.expectEqualStrings(group, res.group);
    try testing.expectEqualStrings(subgroup, res.subgroup);
    try testing.expectEqualStrings("😀", res.emoji);
    try testing.expectEqualStrings("grinning face", res.desc);
}

test "parseGroupLine returns group name" {
    const groupLine = "# group: Smileys & Emotion";
    const expectedGroup = "Smileys & Emotion";
    const resultGroup = parseGroupLine(groupLine);
    try testing.expectEqualStrings(expectedGroup, resultGroup);

    const subgroupLine = "# subgroup: face-smiling";
    const expectedSubgroup = "face-smiling";
    const resultSub = parseGroupLine(subgroupLine);

    try testing.expectEqualStrings(expectedSubgroup, resultSub);
}
