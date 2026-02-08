// SPDX-FileCopyrightText: © 2025 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const version = std.SemanticVersion.parse(b.option([]const u8, "version", "application version string") orelse @import("build.zig.zon").version) catch unreachable;
    const git = b.option([]const u8, "git", "Path to the git executable") orelse "git";
    const gh = b.option([]const u8, "gh", "Path to the gh executable") orelse "gh";

    const options = b.addOptions();
    options.addOption(std.SemanticVersion, "version", version);
    options.addOption(git, "git");
    options.addOption(gh, "gh");

    const exe = b.addExecutable(.{
        .name = "nix-track-pr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addOptions("options", options);

    b.installArtifact(exe);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
