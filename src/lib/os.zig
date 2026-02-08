// SPDX-FileCopyrightText: © 2025 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub const Error = error{NoCacheDir};

pub fn cache(io: std.Io, env: *std.process.Environ.Map) (Error || std.Io.Dir.CreateDirError || std.Io.Dir.OpenError || std.Io.Dir.CreateDirPathOpenError || std.mem.Allocator.Error)!std.Io.Dir {
    var cwd: std.Io.Dir = .cwd();
    var dir = dir: switch (builtin.os.tag) {
        .windows => {
            for (&.{ "XDG_CACHE_DIR", "LOCALAPPDATA" }) |name| {
                if (env.get(name)) |value| {
                    break :dir try cwd.createDirPathOpen(io, value, .{});
                }
            }
            return error.NoCacheDir;
        },
        else => {
            if (env.get("XDG_CACHE_DIR")) |value| break :dir try cwd.createDirPathOpen(io, value, .{});
            if (env.get("HOME")) |value| {
                var home = try cwd.openDir(io, value, .{});
                defer home.close(io);

                home.createDir(io, ".cache", .default_dir) catch |err| switch (err) {
                    error.PathAlreadyExists => {},
                    else => |e| return e,
                };

                break :dir try home.openDir(io, ".cache", .{});
            }
            return error.NoCacheDir;
        },
    };
    defer dir.close(io);

    dir.createDir(io, "nix-track-pr", .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => |e| return e,
    };
    return try dir.openDir(io, "nix-track-pr", .{});
}
