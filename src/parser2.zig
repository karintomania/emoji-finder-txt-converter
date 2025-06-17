const std = @import("std");

// inalid line includes empty lines and non-fully-qualified emojis
const LineType = enum {group, subgroup, emoji, invalid};

pub fn getLineType(line: []const u8) LineType {
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

test "getLineType returns type" {
    const testing = std.testing;

    const test_cases = [_]struct{ expectedType: LineType, line: []const u8 }{
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

    const commentIndex = std.mem.indexOf(u8, line, "#") orelse @panic("failed to parse");
    const comment = std.mem.trim(u8, line[commentIndex + 1..], " ");

    var commentParts = std.mem.splitSequence(u8, comment, " ");

    const emoji = commentParts.next() orelse @panic("No emoji found in line");

    // skip version
    _ = commentParts.next();

    var buffer: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var descList = std.ArrayList([]const u8).init(allocator);
    defer descList.deinit();

    while (commentParts.next()) |part| {
        descList.append(part) catch @panic("Failed to append to descList");
    }

    std.debug.print("emoji = {s}\n", .{emoji});

    const desc = std.mem.join(std.heap.page_allocator, " ", descList.items) catch @panic("Failed to join desc");
    std.debug.print("desc = {s}\n", .{desc});

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
    try testing.expectEqualStrings("😀", res.emoji);
    try testing.expectEqualStrings("grinning face", res.desc);
}