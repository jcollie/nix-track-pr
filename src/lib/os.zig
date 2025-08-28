const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub fn cache(alloc: Allocator) ![]const u8 {
    const dir, const owned = dir: switch (builtin.os.tag) {
        .windows => {
            loop: for (&.{ "XDG_CACHE_DIR", "LOCALAPPDATA" }) |name| {
                if (std.process.getEnvVarOwned(alloc, name)) |value| {
                    break :dir .{ value, true };
                } else |err| switch (err) {
                    error.EnvironmentVariableNotFound => continue :loop,
                    else => return err,
                }
            }
            return error.NoCacheDir;
        },
        else => {
            if (std.posix.getenv("XDG_CACHE_DIR")) |value| break :dir .{ value, false };
            if (std.posix.getenv("HOME")) |value| {
                break :dir .{
                    try std.fs.path.join(alloc, &.{ value, ".cache" }),
                    true,
                };
            }
            return error.NoCacheDir;
        },
    };
    defer if (owned) alloc.free(dir);

    const path = try std.fs.path.join(alloc, &.{
        dir,
        "nix-track-pr",
    });
    errdefer alloc.free(path);

    try std.fs.cwd().makePath(path);

    return path;
}
