const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// inalid line includes empty lines and non-fully-qualified emojis
const LineType = enum { group, subgroup, emoji, invalid };

pub const Emoji = struct {
    emoji: []const u8,
    group: []const u8,
    subgroup: []const u8,
    desc: []const u8,
    keywords: []const []const u8,

      // pub fn format(
      //     self: Emoji,
      //     comptime fmt: []const u8,
      //     options: std.fmt.FormatOptions,
      //     writer: anytype,
      // ) !void {
      //     _ = fmt; _ = options;
      //     try writer.print("Emoji{{ emoji: {s}, group: {s} }}", .{ self.emoji, self.group });
      // }
};

pub const EmojiParser = struct {
    group: []const u8,
    subgroup: []const u8,
    allocator: Allocator,
    map: std.StringHashMap(Emoji),

    pub fn init(allocator: Allocator) EmojiParser {
        return EmojiParser{
            .group = "",
            .subgroup = "",
            .allocator = allocator,
            .map = std.StringHashMap(Emoji).init(allocator),
        };
    }

    pub fn handleLine(
        self: *EmojiParser,
        line: []const u8,
    ) !void {
        const lineType = getLineType(line);
        switch (lineType) {
            .emoji => {
                const emoji = parseEmojiLine(self.group, self.subgroup, line, self.allocator);

                std.debug.print("{s}\n", .{emoji.emoji});
                if (self.map.contains(emoji.emoji)) {
                    // If the emoji already exists, free the allocated description and skip it
                    self.allocator.free(emoji.desc);
                    return;
                }

                try self.map.put(emoji.emoji, emoji);
            },
            .group => {
                self.group = parseGroupLine(line);
            },
            .subgroup => {
                self.subgroup = parseGroupLine(line);
            },
            else => {},
        }
    }

    pub fn deinit(self: *EmojiParser) void {
        var iterator = self.map.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.value_ptr.desc);
        }
        self.map.deinit();
    }
};

fn getLineType(line: []const u8) LineType {
    if (std.mem.indexOf(u8, line, "# group") != null) {
        return LineType.group;
    } else if (std.mem.indexOf(u8, line, "# subgroup") != null) {
        return LineType.subgroup;
    } else if (std.mem.indexOf(u8, line, "fully-qualified") != null) {
        return LineType.emoji;
    } else {
        return LineType.invalid;
    }
}

fn parseEmojiLine(
    group: []const u8,
    subgroup: []const u8,
    line: []const u8,
    allocator: Allocator,
) Emoji {
    const commentIndex = std.mem.indexOf(u8, line, "#") orelse @panic("failed to parse");
    const comment = std.mem.trim(u8, line[commentIndex + 1 ..], " ");

    var commentParts = std.mem.splitSequence(u8, comment, " ");

    const emoji = commentParts.next() orelse @panic("No emoji found in line");

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
    };
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
        "1F603                                                  ; fully-qualified     # 😃 E0.6 grinning face with big eyes",
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

    const big_eye = parser.map.get("😃") orelse {
        try testing.expect(false); // Fail if emoji not found
        return;
    };
    try testing.expectEqualStrings("Smileys & Emotion", big_eye.group);
    try testing.expectEqualStrings("face-smiling", big_eye.subgroup);
    try testing.expectEqualStrings("😃", big_eye.emoji);
    try testing.expectEqualStrings("grinning face with big eyes", big_eye.desc);
    try testing.expectEqual(0, big_eye.keywords.len);
}

test "getLineType returns type" {
    const test_cases = [_]struct { expectedType: LineType, line: []const u8 }{
        .{ .expectedType = LineType.group, .line = "# group: Smileys & Emotion" },
        .{ .expectedType = LineType.subgroup, .line = "# subgroup: face-smiling" },
        .{ .expectedType = LineType.emoji, .line = "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face" },
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

    const res = parseEmojiLine(group, subgroup, emojiLine, testing.allocator);
    defer testing.allocator.free(res.desc);

    try testing.expectEqual(group, res.group);
    try testing.expectEqual(subgroup, res.subgroup);
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
