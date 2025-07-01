const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Emoji = @import("emoji.zig").Emoji;
const ArrayList = std.ArrayList;

// inalid line includes empty lines and non-fully-qualified emojis
const LineType = enum { group, subgroup, emoji, emoji_skin, invalid };

pub fn getLineType(line: []const u8) LineType {
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

pub fn parseEmojiLine(
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

    const keywords: []const []const u8 = undefined;

    return Emoji{
        .group = group,
        .subgroup = subgroup,
        .emoji = emoji,
        .desc = desc,
        .keywords = keywords,
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
pub fn getSkinToneIndex(emoji: *Emoji, line: []const u8, allocator: Allocator) !void {
    const commentIndex = std.mem.indexOf(u8, line, "#") orelse @panic("failed to parse");
    const comment = std.mem.trim(u8, line[commentIndex + 1 ..], " ");

    var commentParts = std.mem.splitSequence(u8, comment, " ");

    const emoji_slice = commentParts.next() orelse @panic("No emoji found in line");

    const emoji_str = try allocator.dupe(u8, emoji_slice);

    if (std.mem.indexOf(u8, line, "1F3FB") != null) {
        try emoji.skin_tones[0].append(emoji_str);
    }
    if (std.mem.indexOf(u8, line, "1F3FC") != null) {
        try emoji.skin_tones[1].append(emoji_str);
    }
    if (std.mem.indexOf(u8, line, "1F3FD") != null) {
        try emoji.skin_tones[2].append(emoji_str);
    }
    if (std.mem.indexOf(u8, line, "1F3FE") != null) {
        try emoji.skin_tones[3].append(emoji_str);
    }
    if (std.mem.indexOf(u8, line, "1F3FF") != null) {
        try emoji.skin_tones[4].append(emoji_str);
    }
}

pub fn parseGroupLine(line: []const u8) []const u8 {
    var it = std.mem.splitSequence(u8, line, ": ");
    _ = it.next();

    const result = it.next() orelse @panic("Failed to parse group line");

    return result;
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
