// SPDX-FileCopyrightText: © 2025 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

const Allocator = std.mem.Allocator;

const os = @import("os.zig");

pub fn dir(io: std.Io, env_map: *std.process.Environ.Map) !std.Io.Dir {
    var cache = try os.cache(io, env_map);
    defer cache.close(io);
    cache.createDir(io, "nixpkgs", .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => |e| return e,
    };
    return try cache.openDir(io, "nixpkgs", .{});
}

pub fn env(alloc: Allocator, env_map: *std.process.Environ.Map) Allocator.Error!std.process.Environ.Map {
    var git_env_map = try env_map.clone(alloc);
    errdefer git_env_map.deinit();

    try git_env_map.put("NO_COLOR", "1");

    return git_env_map;
}

pub fn clone(
    io: std.Io,
    git_dir: std.Io.Dir,
    git_env: *const std.process.Environ.Map,
) !void {
    var exe = try std.process.spawn(
        io,
        .{
            .argv = &.{
                options.git,
                "clone",
                "--bare",
                "https://github.com/NixOS/nixpkgs",
                ".",
            },
            .environ_map = git_env,
            .stdin = .ignore,
            .stdout = .inherit,
            .stderr = .inherit,
            .cwd = .{ .dir = git_dir },
        },
    );

    const rc = try exe.wait(io);
    switch (rc) {
        .exited => |code| {
            if (code == 0) return;
            return error.GitFailed;
        },
        .signal, .stopped, .unknown => return error.GitFailed,
    }
}

pub fn fetch(
    alloc: Allocator,
    io: std.Io,
    branches: [][]const u8,
    git_dir: std.Io.Dir,
    git_env: *const std.process.Environ.Map,
) !void {
    var command: std.ArrayList([]const u8) = .empty;
    defer {
        for (command.items) |arg| alloc.free(arg);
        command.deinit(alloc);
    }
    try command.append(alloc, try alloc.dupe(u8, options.git));
    try command.append(alloc, try alloc.dupe(u8, "fetch"));
    try command.append(alloc, try alloc.dupe(u8, "--prune"));
    try command.append(alloc, try alloc.dupe(u8, "--no-write-fetch-head"));
    try command.append(alloc, try alloc.dupe(u8, "origin"));

    for (branches) |branch| {
        const refspec = try std.fmt.allocPrint(alloc, "{s}:{s}", .{ branch, branch });
        errdefer alloc.free(refspec);
        try command.append(alloc, refspec);
    }

    var exe = try std.process.spawn(
        io,
        .{
            .argv = command.items,
            .environ_map = git_env,
            .stdin = .ignore,
            .stdout = .inherit,
            .stderr = .inherit,
            .cwd = .{ .dir = git_dir },
        },
    );

    const rc = try exe.wait(io);
    switch (rc) {
        .exited => |code| {
            if (code == 0) return;
            return error.GitFailed;
        },
        .signal, .stopped, .unknown => return error.GitFailed,
    }
}

pub fn isAncestor(
    io: std.Io,
    branch: []const u8,
    commit: []const u8,
    git_dir: std.Io.Dir,
    git_env: *const std.process.Environ.Map,
) !bool {
    var exe = try std.process.spawn(
        io,
        .{
            .argv = &.{
                options.git,
                "merge-base",
                "--is-ancestor",
                commit,
                branch,
            },
            .environ_map = git_env,
            .stdin = .ignore,
            .stdout = .inherit,
            .stderr = .inherit,
            .cwd = .{ .dir = git_dir },
        },
    );

    const rc = try exe.wait(io);
    switch (rc) {
        .exited => |code| {
            if (code == 0) return true;
            if (code == 1) return false;
            return error.GitFailed;
        },
        .signal, .stopped, .unknown => return error.GitFailed,
    }
}
