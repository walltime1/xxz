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

    var args = std.process.args();

    var lineStop: u8 = 16;
    var wordLength: u8 = 4;
    var fileNamePointer: [:0]const u8 = "";

    while (args.next()) |arg| {
        const param = std.meta.stringToEnum(possibleParam, arg) orelse continue;
        switch (param) {
            // find parameter -w to set the width.
            // if it is unset then use 16
            .@"-w" => {
                const tempRead: [:0]const u8 = args.next() orelse break;
                lineStop = readReal(tempRead, lineStop) catch argsError.wrongWidth;
            },

            // find parameter -l to set the word length.
            // if it is unset then use 1
            .@"-l" => {
                const tempRead: [:0]const u8 = args.next() orelse break;
                wordLength = readReal(tempRead, wordLength) catch argsError.wrongLengh;
            },

            // read file name
            .@"-f" => {
                const tempRead: [:0]const u8 = args.next() orelse break;
                fileNamePointer = tempRead;
            },
            //else => continue,
        }
    }

    if (fileNamePointer.len == 0) return argsError.wrongFileName;

    // determine your directory
    const cwd = std.fs.cwd();

    // this is optional
    const file = try cwd.openFile(fileNamePointer, .{});
    defer file.close();

    const fileSize = (try file.stat()).size;

    const buffer = try allocator.alloc(u8, fileSize);

    // read into an array
    try file.reader().readNoEof(buffer);

    // print file content as a series of hexes
    // how we need to add N columns
    // 0x00: 0 1 2 3 4 5 6 7 8 9 a b c d e f mod 0d16 or 0x10
    // 0x10: 0 1 2 3 4 5 6 7 8 9 a b c d e f mod

    print("\n@hexdump: ", .{});
    for (0..lineStop) |i| {
        // print position
        print("{x:0>2}", .{i});
        // print end of a word
        if (i % wordLength == wordLength - 1)
            print(" ", .{});
    }
    print("\n", .{});

    // main file read loop
    // in order to achieve true hexdump i need to
    // create a string and populate it with
    // possible printable characters

    // var line: = [_]u8{'.'} ** lineStop;
    var line = try allocator.alloc(u8, lineStop);

    for (line, 0..) |_, place| {
        line[place] = '.';
    }

    // var content: [64]u8 = [_]u8{'A'} ** 64;

    // loop to the end of the file size
    for (0..fileSize) |i| {

        // read one character
        const char = buffer[i];

        // when we reach the end of a line
        if (i % lineStop == 0) {

            // but not the end of the first line
            // print the printable line and a newline
            if (i != 0x0) {
                print("| {s}\n", .{line});
                for (line, 0..) |_, place| {
                    line[place] = '.';
                }
            }

            // print the start of a new line and its offest
            print("{x:0>8}: ", .{i});
            // clear the printable line
        }

        // if char is printable add it to the end string
        line[i % lineStop] = printable(char) catch '.';

        // print a char hex
        print("{x:0>2}", .{char});
        // print end of a word
        if (i % wordLength == wordLength - 1 or i == fileSize - 1) print(" ", .{});

        if (i == fileSize - 1) {
            for (i..(lineStop % fileSize + fileSize) - 2) |t| {
                print("  ", .{});
                if (t % wordLength == wordLength - 1) print(" ", .{});
            }
            print("| {s}\n", .{line});
        }
    }
}

fn printable(char: u8) !u8 {
    // if char in range return char
    // else return error
    if (char > 31 and char != 127) return char;
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

test "modulo" {
    try testing.expect(0x10 % 0x10 == 0);
    try testing.expect(0x11 % 0x10 == 1);

    // Now we test if the function returns an error
    // if we pass a zero as denominator.
    // But which error needs to be tested?
    // try testing.expectError(error.DivisionByZero, divide(15, 0));
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

//alternative allocator
//using GeneralPurposeAllocator. you can learn more about allocators in https://youtu.be/vHWiDx_l4V0

//const std = @import("std");

//pub fn main() !void {
//    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//    defer _ = gpa.deinit();
//    const allocator = &gpa.allocator;
//    const args = try std.process.argsAlloc(allocator);
//    defer std.process.argsFree(allocator, args);
//    const file = try std.fs.cwd().openFile(args[1], .{});
//    const file_content = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB max read size
//    defer allocator.free(file_content);
//    std.debug.print("{s}", .{file_content});
//}

// TESTS
