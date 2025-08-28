const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

const gh = @import("lib/gh.zig");
const git = @import("lib/git.zig");
const nixpkgs = @import("lib/nixpkgs.zig");

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !u8 {
    const alloc, const is_debug = allocator: {
        break :allocator switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var stdout_buffer: [64]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const pr_numbers = prs: {
        var l: std.ArrayList(u64) = .empty;
        errdefer l.deinit(alloc);

        var args = try std.process.argsWithAllocator(alloc);
        errdefer args.deinit();

        _ = args.skip();
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "--version")) {
                std.debug.print("nix-track-pr {f}\n", .{options.version});
                return 0;
            }

            const pr = std.fmt.parseUnsigned(u64, arg, 10) catch |err| {
                std.debug.print("PR numbers must be valid integers. ({t})\n", .{err});
                return 1;
            };
            try l.append(alloc, pr);
        }
        break :prs try l.toOwnedSlice(alloc);
    };
    defer alloc.free(pr_numbers);

    if (pr_numbers.len == 0) {
        std.debug.print("I need least one PR number!\n", .{});
        return 1;
    }

    const git_dir = try git.dir(alloc);
    defer alloc.free(git_dir);

    nixpkgs: {
        {
            var dir = std.fs.openDirAbsolute(git_dir, .{}) catch |err| switch (err) {
                error.FileNotFound => {
                    try git.clone(alloc, git_dir);
                    break :nixpkgs;
                },
                else => |e| return e,
            };
            defer dir.close();
        }
        try git.fetch(alloc, git_dir);
    }

    var prs: std.ArrayList(gh.PR) = .empty;
    defer {
        for (prs.items) |pr| pr.deinit(alloc);
        prs.deinit(alloc);
    }

    for (pr_numbers) |pr_number| {
        const pr = try gh.PR.view(alloc, pr_number, git_dir) orelse {
            std.debug.print("{d} does not appear to be a valid PR number!\n", .{pr_number});
            continue;
        };
        try prs.append(alloc, pr);
    }

    // minimum width of title field needs to be at least 6
    var max_title_len: usize = 6;
    for (prs.items) |pr| {
        if (pr.title.len > max_title_len) max_title_len = pr.title.len;
    }

    for (prs.items, 0..) |pr, i| {
        if (i == 0) {
            try stdout.writeAll("┏");
            try stdout.writeAll("━" ** 8);
            try stdout.writeAll("┯");
            try stdout.writeAll("━" ** 8);
            try stdout.writeAll("┯");
            for (0..max_title_len + 2) |_| try stdout.writeAll("━");
            try stdout.writeAll("┓\n");
        } else {
            try stdout.writeAll("┣");
            try stdout.writeAll("━" ** 8);
            try stdout.writeAll("┯");
            try stdout.writeAll("━" ** 8);
            try stdout.writeAll("┯");
            try stdout.writeAll("━" ** 4);
            try stdout.writeAll("┷");
            for (0..max_title_len - 3) |_| try stdout.writeAll("━");
            try stdout.writeAll("┫\n");
        }

        try stdout.print("┃ {d:>6} │ {t:<6} │ {s}", .{ pr.number, pr.state, pr.title });
        for (0..max_title_len - pr.title.len + 1) |_| try stdout.writeAll(" ");
        try stdout.writeAll("┃\n");

        {
            try stdout.writeAll("┠");
            try stdout.writeAll("─" ** 8);
            try stdout.writeAll("┴");
            try stdout.writeAll("─" ** 8);
            try stdout.writeAll("┴");
            try stdout.writeAll("─" ** 4);
            try stdout.writeAll("┬");
            for (0..max_title_len - 3) |_| try stdout.writeAll("─");
            try stdout.writeAll("┨\n");
        }
        try stdout.flush(); // Don't forget to flush!

        const branches_to_check = try nixpkgs.branchesToCheck(alloc, pr.base_ref);
        defer {
            for (branches_to_check) |branch| alloc.free(branch);
            alloc.free(branches_to_check);
        }

        for (branches_to_check) |branch| {
            merged: {
                if (pr.commit) |commit| {
                    if (try git.isAncestor(alloc, branch, commit, git_dir)) {
                        try stdout.print("┃ {s:<20} │ 🟢", .{branch});
                        break :merged;
                    }
                }
                try stdout.print("┃ {s:<20} │ 🔴", .{branch});
            }
            for (0..max_title_len - 6) |_| try stdout.writeAll(" ");
            try stdout.writeAll("┃\n");

            try stdout.flush(); // Don't forget to flush!
        }
    }
    {
        try stdout.writeAll("┗");
        try stdout.writeAll("━" ** 22);
        try stdout.writeAll("┷");
        for (0..max_title_len - 3) |_| try stdout.writeAll("━");
        try stdout.writeAll("┛\n");
    }

    try stdout.flush(); // Don't forget to flush!

    return 0;
}
