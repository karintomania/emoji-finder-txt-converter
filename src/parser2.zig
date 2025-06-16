const std = @import("std");

// inalid line includes empty lines and non-fully-qualified emojis
const LineType = enum {group, subgroup, emoji, invalid};

pub fn checkLineType(line: []const u8) LineType {
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

test "testEmoji adds" {
    const testing = std.testing;

    const test_cases = [_]struct{ expectedType: LineType, line: []const u8 }{
        .{ .expectedType = LineType.group, .line = "# group: Smileys & Emotion" },
        .{ .expectedType = LineType.subgroup, .line = "# subgroup: face-smiling" },
        .{ .expectedType = LineType.emoji, .line = "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face" },
        .{ .expectedType = LineType.invalid, .line = "1F636 200D 1F32B                                       ; minimally-qualified # 😶‍🌫 E13.1 face in clouds" },
    };

    for (test_cases) |test_case| {
        const result = checkLineType(test_case.line);

        try testing.expectEqual(test_case.expectedType, result);
    }
}

pub const Emoji = struct {
    emoji: []const u8,
    group: []const u8,
    subgroup: []const u8,
    desc: []const u8,
    keywords: []const []const u8,
};


pub fn parseEmojiLine(
    group: []const u8,
    subgroup: []const u8,
    line: []const u8,
) Emoji {
    var afterHashTag = std.mem.splitSequence(u8, line, "#");
    var s = std.mem.splitSequence(u8, afterHashTag.first(), " ");

    const emoji = s.next() orelse "";
    std.debug.print("emoji = {s}", .{emoji});
    const desc = s.next() orelse "";
    std.debug.print("desc = {s}", .{desc});

    return Emoji{
        .group= group,
        .subgroup= subgroup,
        .emoji= emoji,
        .desc= desc,
        .keywords = &.{},
    };
}

test "parseEmojiLine returns parsed Emoji" {
    const testing = std.testing;

    const emojiLine = "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face";

    const group = "Smileys & Emotion";
    const subgroup = "face-smiling";

    const res = parseEmojiLine(group, subgroup, emojiLine);

    try testing.expectEqual(group, res.group);
    try testing.expectEqual(subgroup, res.subgroup);
    try testing.expectEqual("😀", res.emoji);
    try testing.expectEqual(group, res.desc);
}