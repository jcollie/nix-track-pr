const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;

const os = @import("os.zig");

pub fn dir(alloc: Allocator) ![]const u8 {
    const cache = try os.cache(alloc);
    defer alloc.free(cache);
    return std.fs.path.join(alloc, &.{
        cache,
        "nixpkgs",
    });
}

pub fn clone(alloc: Allocator, git_dir: []const u8) !void {
    var env_map = try std.process.getEnvMap(alloc);
    defer env_map.deinit();
    try env_map.put("NO_COLOR", "1");

    var exe: std.process.Child = .init(
        &.{
            "git",
            "clone",
            "--bare",
            "https://github.com/NixOS/nixpkgs",
            git_dir,
        },
        alloc,
    );

    exe.env_map = &env_map;
    exe.stdin_behavior = .Ignore;
    exe.stdout_behavior = .Inherit;
    exe.stderr_behavior = .Inherit;

    try exe.spawn();
    const rc = try exe.wait();
    switch (rc) {
        .Exited => |code| {
            if (code == 0) return;
            return error.GitFailed;
        },
        .Signal, .Stopped, .Unknown => return error.GitFailed,
    }
}

pub fn fetch(alloc: Allocator, git_dir: []const u8) !void {
    var env_map = try std.process.getEnvMap(alloc);
    defer env_map.deinit();
    try env_map.put("NO_COLOR", "1");

    var exe: std.process.Child = .init(
        &.{
            "git",
            "fetch",
            "origin",
            "--prune",
            "--no-write-fetch-head",
        },
        alloc,
    );

    exe.cwd = git_dir;
    exe.env_map = &env_map;
    exe.stdin_behavior = .Ignore;
    exe.stdout_behavior = .Inherit;
    exe.stderr_behavior = .Inherit;

    try exe.spawn();
    const rc = try exe.wait();
    switch (rc) {
        .Exited => |code| {
            if (code == 0) return;
            return error.GitFailed;
        },
        .Signal, .Stopped, .Unknown => return error.GitFailed,
    }
}

pub fn isAncestor(alloc: Allocator, branch: []const u8, commit: []const u8, git_dir: []const u8) !bool {
    var env_map = try std.process.getEnvMap(alloc);
    defer env_map.deinit();
    try env_map.put("NO_COLOR", "1");

    var exe: std.process.Child = .init(
        &.{
            "git",
            "merge-base",
            "--is-ancestor",
            commit,
            branch,
        },
        alloc,
    );

    exe.cwd = git_dir;
    exe.env_map = &env_map;
    exe.stdin_behavior = .Ignore;
    exe.stdout_behavior = .Ignore;
    exe.stderr_behavior = .Ignore;

    try exe.spawn();
    const rc = try exe.wait();
    switch (rc) {
        .Exited => |code| {
            if (code == 0) return true;
            if (code == 1) return false;
            return error.GitFailed;
        },
        .Signal, .Stopped, .Unknown => return error.GitFailed,
    }
}
