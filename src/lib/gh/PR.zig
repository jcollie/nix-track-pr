// SPDX-FileCopyrightText: © 2025 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const PR = @This();

const std = @import("std");
const options = @import("options");

const Allocator = std.mem.Allocator;

const collect = @import("../collect.zig").collect;

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

pub fn view(alloc: Allocator, io: std.Io, pr_number: u64, git_dir: std.Io.Dir, git_env: *const std.process.Environ.Map) !?PR {
    const str = try std.fmt.allocPrint(alloc, "{d}", .{pr_number});
    defer alloc.free(str);

    var exe = try std.process.spawn(
        io,
        .{
            .argv = &.{
                options.gh,
                "pr",
                "view",
                str,
                "--json",
                "baseRefName,mergeCommit,state,title",
            },
            .environ_map = git_env,
            .cwd = .{ .dir = git_dir },
            .stdin = .ignore,
            .stdout = .pipe,
            .stderr = .inherit,
        },
    );

    var collect_stdout = try io.concurrent(
        collect,
        .{ alloc, io, exe.stdout },
    );
    defer _ = collect_stdout.cancel(io) catch {};

    const stdout = try collect_stdout.await(io);
    defer alloc.free(stdout);

    const rc = try exe.wait(io);
    switch (rc) {
        .exited => |code| {
            if (code != 0) return null;
        },
        .signal, .stopped, .unknown => return error.GHFailed,
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
        stdout,
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
