const std = @import("std");
const testing = std.testing;
const print = std.debug.print;

const printError = error{notPrintable};
const zeroError = error{isZero};
const argsError = error{
    wrongWidth,
    wrongLength,
    wrongFileName,
};

const possibleParam = enum { @"-w", @"-l", @"-f" };
pub fn main() !void {
    const out = std.io.getStdOut().writer();

    // alloc buffer
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    //_ = allocator;
    const args = std.process.argsAlloc(allocator) catch return;
    defer std.process.argsFree(allocator, args);

    var lineStop: u8 = 16;
    var wordLength: u8 = 4;
    var fileNamePointer: [:0]const u8 = "";

    for (args, 0..) |arg, i| {
        const param = std.meta.stringToEnum(possibleParam, arg) orelse continue;
        switch (param) {
            // find parameter -w to set the width.
            // if it is unset then use 16
            .@"-l" => {
                if (i < args.len - 1) {
                    const tempRead = args[i + 1];
                    lineStop = std.fmt.parseUnsigned(u8, tempRead, 10) catch lineStop;
                }
            },

            // find parameter -l to set the word length.
            // if it is unset then use 1
            .@"-w" => {
                if (i < args.len - 1) {
                    const tempRead: [:0]const u8 = args[i + 1];
                    wordLength = std.fmt.parseUnsigned(u8, tempRead, 10) catch wordLength;
                }
            },

            // read file name
            .@"-f" => {
                if (i < args.len - 1) {
                    const tempRead: [:0]const u8 = args[i + 1];
                    fileNamePointer = tempRead;
                }
            },
            //else => continue,
        }
    }

    const cwd = std.fs.cwd();
    if (fileNamePointer.len == 0) fileNamePointer = args[args.len - 1];

    var in = std.io.getStdIn();
    if (fileNamePointer.len != 0) {
        in = try cwd.openFile(fileNamePointer, .{});
    }
    defer in.close();

    //const in = std.io.getStdIn();

    var bufRead = std.io.bufferedReader(in.reader());

    const buffer = try allocator.alloc(u8, lineStop);
    defer allocator.free(buffer);

    var offset: i64 = 0;

    // main file read loop
    while (true) {
        // read into an array
        const bytesRead = try bufRead.reader().read(buffer);
        if (bytesRead == 0) break;

        // print file content as a series of hexes
        // how we need to add N columns
        // 0x00: 0 1 2 3 4 5 6 7 8 9 a b c d e f mod 0d16 or 0x10
        // 0x10: 0 1 2 3 4 5 6 7 8 9 a b c d e f mod

        // in order to achieve true hexdump i need to
        // create a string and populate it with
        // possible printable characters
        try printHexdump(buffer[0..bytesRead], lineStop, wordLength, offset, out);
        offset += @intCast(buffer.len);
    }

    // last read;

}

fn printable(char: u8) !u8 {
    // if char in range return char
    // else return error
    if (char > 31 and char < 127) return char;
    return printError.notPrintable;
}

fn notZero(comptime numb: u8) !u8 {
    if (numb > 0) return numb;
    return zeroError.isZero;
}

fn printHexdump(buffer: []const u8, lineLen: u8, wordLength: u8, offset: i64, out: anytype) !void {
    //const out = std.io.getStdOut().writer();

    try out.print("{x:0>8}: ", .{offset});

    const empty: [129]u8 = [_]u8{' '} ** 129;

    // variable for a printable string
    var printableStr: [0xff]u8 = undefined;
    var whitespaces: u8 = lineLen / wordLength;
    // Print the hex values
    for (0..buffer.len) |i| {
        const byte = buffer[i];
        try out.print("{x:0>2}", .{byte});
        printableStr[i] = printable(byte) catch '.';
        if (i % wordLength == wordLength - 1) {
            try out.print(" ", .{});
            whitespaces -= 1;
        }
    }
    //fill the gap if read less bytes than the buffer
    const wsCount = (lineLen - buffer.len) * 2 + (buffer.len % wordLength) + whitespaces;
    try out.print("{s}:{s}\n", .{ empty[0..wsCount], printableStr[0..buffer.len] });
}

fn processExample1() void {}

test "modulo" {
    try testing.expect(0x10 % 0x10 == 0);
    try testing.expect(0x11 % 0x10 == 1);
}

test "load_string" {
    const lineStop = 2;
    const i = 0;
    const char: u8 = 't';
    var line: [lineStop]u8 = [_]u8{'.'} ** lineStop;

    line[i % lineStop] = printable(char) catch '.';

    try testing.expect(line[0] == char);
}

// test to see how args are parsed actually
test "args test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    print("args test:\nThere are {d} args:\n", .{args.len});
    for (args) |arg| {
        print("\t{s}\n", .{arg});
    }
}

test "args test 2" {
    var args = std.process.args();
    print("args test 2:\n", .{});
    while (args.next()) |arg| {
        print("\t{s}\n", .{arg});
    }
}

test "zero error test" {
    print("notZero:\n", .{});
    print("\ttest: {any}\n", .{notZero(4)});
    try testing.expectEqual(3, notZero(3));

    print("\ttest: {any}\n", .{notZero(0)});
    try testing.expectError(zeroError.isZero, notZero(0));
}

//alternative allocator
//using GeneralPurposeAllocator. you can learn more about allocators in https://youtu.be/vHWiDx_l4V0

test "fixed buffer allocator" {
    var buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const memory = try allocator.alloc(u8, 100);
    defer allocator.free(memory);

    try testing.expect(memory.len == 100);
    try testing.expect(@TypeOf(memory) == []u8);
}

// https://zig.news/xq/cool-zig-patterns-comptime-string-interning-3558
//fn internString(comptime str: []const u8) []const u8 {
//    return internStringBuffer(str.len, str[0..str.len].*);
//}

//fn internStringBuffer(comptime len: comptime_int, comptime items: [len]u8) []const u8 {
//    comptime var storage: [len]u8 = items;
//    return &storage;
//}
