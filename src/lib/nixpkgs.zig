// SPDX-FileCopyrightText: © 2025 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn branchesToCheck(alloc: Allocator, branch: []const u8) ![][]const u8 {
    const release_prefix = "release-";

    var list: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (list.items) |item| alloc.free(item);
        list.deinit(alloc);
    }

    if (std.mem.startsWith(u8, branch, release_prefix)) {
        const release = branch[release_prefix.len..];
        try list.append(alloc, try std.fmt.allocPrint(alloc, "release-{s}", .{release}));
        try list.append(alloc, try std.fmt.allocPrint(alloc, "nixpkgs-{s}-darwin", .{release}));
        try list.append(alloc, try std.fmt.allocPrint(alloc, "nixos-{s}-small", .{release}));
        try list.append(alloc, try std.fmt.allocPrint(alloc, "nixos-{s}", .{release}));
        return list.toOwnedSlice(alloc);
    }

    if (std.mem.eql(u8, branch, "staging")) {
        const branches = [_][]const u8{
            "staging",
            "staging-next",
        };
        for (branches) |b| {
            try list.append(alloc, try alloc.dupe(u8, b));
        }
    }

    if (std.mem.eql(u8, branch, "staging-next")) {
        const branches = [_][]const u8{
            "staging-next",
        };
        for (branches) |b| {
            try list.append(alloc, try alloc.dupe(u8, b));
        }
    }

    const branches = [_][]const u8{
        "master",
        "nixos-unstable-small",
        "nixpkgs-unstable",
        "nixos-unstable",
    };
    for (branches) |b| {
        try list.append(alloc, try alloc.dupe(u8, b));
    }

    return list.toOwnedSlice(alloc);
}
