/// author: @strozz1
/// this is my first program with Zig.
/// I don't expect it to be perfect and efficient. I'm learning the language.
/// Any suggestions and improvements are welcome
const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
const FlagError = error{
    unknownFlag,
};
const Flag = enum {
    lines,
    words,
    bytes,
    chars,
};
const flags_size = @typeInfo(Flag).Enum.fields.len;

pub fn main() !void {
    var file: std.fs.File = undefined;
    var file_name: ?[]const u8 = null;
    const alloc = std.heap.page_allocator;
    var args = try std.process.ArgIterator.initWithAllocator(alloc);
    defer args.deinit();

    //flag check
    var flags = [4]bool{ false, false, false, false };

    _ = args.skip(); //skip zig

    // check if arguments are valid and set the corresponding flags
    while (args.next()) |v| {
        if (v.len > 1 and std.mem.startsWith(u8, v, "-")) {
            flags = parseFlag(v, flags) catch |e| {
                try stderr.print("Failed to parse flag: {s}", .{@errorName(e)});
                return;
            };
        } else {
            file_name = v;
        }
    }

    //check if we have a file_name and open it. return if error
    if (file_name) |f| {
        file = std.fs.cwd().openFile(f, .{}) catch |e| {
            try stderr.print("Failed to open file: {s}", .{@errorName(e)});
            return;
        };
    } else {
        //if no file provided, set file to stdin
        file = std.io.getStdIn();
    }

    //if no flags, then set default flags
    if (zeroFlags(flags)) {
        flags[0] = true;
        flags[1] = true;
        flags[2] = true;
    }
    for (flags, 0..) |f, i| {
        if (f) try stdout.print("  {d}", .{parseFile(file, @enumFromInt(i))});
        file.seekTo(0) catch continue;
    }
    if (file_name) |f| try stdout.print("  {s}", .{f});
    try stdout.print("\n", .{});

    file.close();
}

/// check if no flags where provided
fn zeroFlags(flags: [flags_size]bool) bool {
    for (flags) |f| {
        if (f) return false;
    }
    return true;
}
fn parseFlag(flag: [:0]const u8, flags: [flags_size]bool) FlagError![flags_size]bool {
    var res = flags;
    switch (flag[1]) {
        'l' => res[0] = true,
        'w' => res[1] = true,
        'c' => res[2] = true,
        'm' => res[3] = true,
        else => return FlagError.unknownFlag,
    }
    return res;
}

fn parseFile(file: std.fs.File, f: Flag) u32 {
    return switch (f) {
        Flag.chars => readChars(file),
        Flag.lines => readLines(file),
        Flag.bytes => readBytes(file),
        Flag.words => readWords(file),
    };
}

fn readLines(file: std.fs.File) u32 {
    var reader = file.reader();
    var count: u32 = 0;
    var eof: bool = false;
    var b: u8 = undefined;
    while (!eof) {
        b = reader.readByte() catch {
            eof = true;
            continue;
        };
        if (b == '\n') {
            count += 1;
        }
    }
    return count;
}
fn readBytes(file: std.fs.File) u32 {
    var reader = file.reader();
    var count: u32 = 0;
    while (true) {
        _ = reader.readByte() catch {
            break;
        };
        count += 1;
    }
    return count;
}
///Read one byte at a time and check if is a valid 'jump' of word. If so check if length>0.
///File: must be a valid and open file
fn readWords(file: std.fs.File) u32 {
    var reader = file.reader();
    var count: u32 = 0;
    var eof: bool = false;
    var b: u8 = undefined;
    var size: u32 = 0;
    while (!eof) {
        b = reader.readByte() catch {
            if (size > 0)
                size += 1;
            eof = true;
            continue;
        };

        if ((b == ' ' or b == '\n' or b == '\t' or b == '\r')) {
            if (size > 0) {
                count += 1;
                size = 0;
            }
        } else size += 1;
    }
    return count;
}
/// Count chars one by one
fn readChars(file: std.fs.File) u32 {
    var reader = file.reader();
    var count: u32 = 0;
    var eof: bool = false;
    var b: u8 = undefined;
    while (!eof) {
        b = reader.readByte() catch {
            eof = true;
            continue;
        };
        if ((b <= 0x7f) or (b >= 0xc0 and b <= 0xf7)) {
            count += 1;
        }
    }
    return count;
}
