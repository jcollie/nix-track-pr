const PR = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const State = enum {
    closed,
    merged,
    open,
};

number: u64,
state: State,
title: []const u8,
base_ref: []const u8,
commit: ?[]const u8,

pub fn view(alloc: Allocator, pr_number: u64, git_dir: []const u8) !?PR {
    const str = try std.fmt.allocPrint(alloc, "{d}", .{pr_number});
    defer alloc.free(str);

    var env_map = try std.process.getEnvMap(alloc);
    defer env_map.deinit();
    try env_map.put("NO_COLOR", "1");

    var exe: std.process.Child = .init(
        &.{
            "gh",
            "pr",
            "view",
            str,
            "--json",
            "baseRefName,mergeCommit,state,title",
        },
        alloc,
    );

    exe.env_map = &env_map;
    exe.cwd = git_dir;

    exe.stdin_behavior = .Ignore;
    exe.stdout_behavior = .Pipe;
    exe.stderr_behavior = .Pipe;

    var stdout: std.ArrayList(u8) = .empty;
    defer stdout.deinit(alloc);

    var stderr: std.ArrayList(u8) = .empty;
    defer stderr.deinit(alloc);

    try exe.spawn();
    try exe.collectOutput(alloc, &stdout, &stderr, std.math.maxInt(u16));
    const rc = try exe.wait();
    switch (rc) {
        .Exited => |code| {
            if (code != 0) return null;
        },
        .Signal, .Stopped, .Unknown => return error.GHFailed,
    }

    const Result = struct {
        state: []const u8,
        title: []const u8,
        baseRefName: []const u8,
        mergeCommit: ?struct {
            oid: []const u8,
        },
    };

    const parsed = try std.json.parseFromSlice(
        Result,
        alloc,
        stdout.items,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const lower = try std.ascii.allocLowerString(alloc, parsed.value.state);
    defer alloc.free(lower);

    const state = std.meta.stringToEnum(State, lower) orelse return null;

    const title = try alloc.dupe(u8, parsed.value.title);
    errdefer alloc.free(title);

    const base_ref = try alloc.dupe(u8, parsed.value.baseRefName);
    errdefer alloc.free(base_ref);

    const commit = if (parsed.value.mergeCommit) |commit| try alloc.dupe(u8, commit.oid) else null;
    errdefer if (commit) |v| alloc.free(v);

    return .{
        .number = pr_number,
        .state = state,
        .title = title,
        .base_ref = base_ref,
        .commit = commit,
    };
}

pub fn deinit(self: *const PR, alloc: Allocator) void {
    alloc.free(self.title);
    alloc.free(self.base_ref);
    if (self.commit) |commit| alloc.free(commit);
}
