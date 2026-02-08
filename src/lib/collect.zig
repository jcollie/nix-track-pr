// SPDX-FileCopyrightText: © 2025 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

const std = @import("std");

pub fn collect(alloc: std.mem.Allocator, io: std.Io, file_: ?std.Io.File) ![]const u8 {
    const file = file_ orelse return error.NoFile;
    var writer: std.Io.Writer.Allocating = .init(alloc);
    defer writer.deinit();
    var buf: [64]u8 = undefined;
    var reader = file.reader(io, &buf);
    _ = try reader.interface.streamRemaining(&writer.writer);
    return writer.toOwnedSlice();
}
