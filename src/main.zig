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
            .@"-w" => {
                if (i < args.len - 1) {
                    const tempRead = args[i + 1];
                    lineStop = readReal(tempRead, lineStop) catch argsError.wrongWidth;
                }
            },

            // find parameter -l to set the word length.
            // if it is unset then use 1
            .@"-l" => {
                if (i < args.len - 1) {
                    const tempRead: [:0]const u8 = args[i + 1];
                    wordLength = readReal(tempRead, wordLength) catch argsError.wrongLengh;
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

    //var buffer: [1024]u8 = undefined;
    const buffer = try allocator.alloc(u8, lineStop);

    printHeader(lineStop, wordLength);

    var offset: i64 = 0;

    // main file read loop
    while (true) {
        // read into an array
        const bytesRead = try bufRead.reader().readAtLeast(buffer, lineStop);

        // print file content as a series of hexes
        // how we need to add N columns
        // 0x00: 0 1 2 3 4 5 6 7 8 9 a b c d e f mod 0d16 or 0x10
        // 0x10: 0 1 2 3 4 5 6 7 8 9 a b c d e f mod

        // in order to achieve true hexdump i need to
        // create a string and populate it with
        // possible printable characters
        try printHexdump2(buffer, bytesRead, wordLength, offset);
        offset += @intCast(buffer.len);

        if (bytesRead != lineStop) break;
    }

    // last read;

}

fn printable(char: u8) !u8 {
    // if char in range return char
    // else return error
    if (char > 31 and char < 127) return char;
    return printError.notPrintable;
}

fn notZero(numb: u8) !u8 {
    if (numb > 0) return numb;
    return zeroError.isZero;
}

fn readReal(str: []const u8, backup: u8) !u8 {
    const retVal: u8 = std.fmt.parseUnsigned(u8, str, 10) catch backup;
    if (retVal <= 0) {
        std.debug.print("DEBUG: [{d}] is less than 1, falling back to {d}!\n", .{ retVal, backup });
        return backup;
    }
    return retVal;
}

fn printHeader(lineStop: u8, wordLength: u8) void {
    print("\n@hexdump: ", .{});
    for (0..lineStop) |i| {
        // print position
        print("{x:0>2}", .{i});
        // print end of a word
        if (i % wordLength == wordLength - 1)
            print(" ", .{});
    }
    print("\n", .{});
}

fn printHexdump2(buffer: []const u8, bufferLen: usize, wordLength: u8, offset: i64) !void {
    print("{x:0>8}: ", .{offset});

    // Print the hex values
    for (0..bufferLen) |i| {
        const byte = buffer[i];
        print("{x:0>2}", .{byte});
        if (i % wordLength == wordLength - 1) print(" ", .{});
    }
    //fill the gap if read less bytes than the buffer
    for (bufferLen..buffer.len) |i| {
        print("  ", .{});
        if (i % wordLength == wordLength - 1) print(" ", .{});
    }
    print(" :", .{});
    // Print the printable characters
    for (0..bufferLen) |i| {
        const byte = buffer[i];
        const res: u8 = printable(byte) catch '.';
        print("{c}", .{res});
    }
    print("\n", .{});
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

test "param val to u8" {
    print("param val to u8:\n", .{});
    print("\t", .{});
    try testing.expectEqual(readReal("11", 1), 11);
    try testing.expectEqual(readReal("1111", 0), 0);
    print("\n", .{});
}

test "printHeader" {
    printHeader(4, 1);
    printHeader(32, 4);
    printHeader(16, 2);
}

test "print Hex" {
    // difference  between []u8 []const u8?
    const text: []const u8 = "12345678";
    //const text: []u8 = &txt;
    try printHexdump2(text, 8, 1, 4);
    try printHexdump2(text, 3, 1, 4);
    try printHexdump2(text, 8, 2, 4);
}
//alternative allocator
//using GeneralPurposeAllocator. you can learn more about allocators in https://youtu.be/vHWiDx_l4V0
