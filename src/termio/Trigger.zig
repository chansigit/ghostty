//! A trigger sends text to the pty when the text before the cursor matches
//! a regular expression. See the `trigger` config option.
const Trigger = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const oni = @import("oniguruma");
const configpkg = @import("../config.zig");

regex: oni.Regex,

/// The text to send, with escapes already decoded. Owned by the caller's
/// allocator (an arena in practice).
text: []const u8,

/// True once the trigger fired for the current matching line. It is
/// cleared when the line stops matching so it fires once per match.
fired: bool = false,

/// Parse a `REGEX=>TEXT` value. The value is split at the first `=>`.
pub fn init(alloc: Allocator, value: []const u8) !Trigger {
    const idx = std.mem.indexOf(u8, value, "=>") orelse return error.InvalidValue;

    var regex = try oni.Regex.init(
        value[0..idx],
        .{},
        oni.Encoding.utf8,
        oni.Syntax.default,
        null,
    );
    errdefer regex.deinit();

    // The decoded text is never longer than the encoded text.
    const buf = try alloc.alloc(u8, value.len - idx - 2);
    const text = try configpkg.string.parse(buf, value[idx + 2 ..]);
    return .{ .regex = regex, .text = text };
}

pub fn deinit(self: *Trigger) void {
    self.regex.deinit();
}

/// Bounds the backtracking work of one search. Matching runs with the
/// renderer lock held, so a pathological regex must not stall the terminal.
const search_retry_limit = 100_000;

/// Returns true if the regex matches anywhere in the given line.
pub fn matches(self: *Trigger, line: []const u8) bool {
    var param = oni.MatchParam.init() catch return false;
    defer param.deinit();
    param.setRetryLimitInSearch(search_retry_limit) catch return false;

    var region = self.regex.searchWithParam(line, .{}, &param) catch return false;
    region.deinit();
    return true;
}

test "init splits at the first arrow and decodes escapes" {
    const testing = std.testing;
    try oni.testing.ensureInit();
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var t: Trigger = try .init(arena.allocator(), "(?i)pass.*:\\s*$=>a=>b\\r\\x41");
    defer t.deinit();
    try testing.expectEqualStrings("a=>b\rA", t.text);
    try testing.expect(t.matches("Password: "));
    try testing.expect(!t.matches("Password: x"));
}

test "init rejects invalid values" {
    const testing = std.testing;
    try oni.testing.ensureInit();
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(error.InvalidValue, Trigger.init(arena.allocator(), "no arrow"));
    try testing.expectError(error.InvalidString, Trigger.init(arena.allocator(), "a=>\\xZ"));
}
