const std = @import("std");
const testing = std.testing;

const printError = error{notPrintable};

pub fn main() !void {
    // read filename

    // determine your directory
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("test.txt", .{});
    defer file.close();

    const fileSize = (try file.stat()).size;

    // alloc buffer
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const buffer = try allocator.alloc(u8, fileSize);

    // read into an array
    try file.reader().readNoEof(buffer);

    // print file content as a series of hexes
    // how we need to add N columns
    // 0x00: 0 1 2 3 4 5 6 7 8 9 a b c d e f mod 0d16 or 0x10
    // 0x10: 0 1 2 3 4 5 6 7 8 9 a b c d e f mod

    const lineStop: u8 = 0x10;

    std.debug.print("@hexdump: ", .{});
    for (0..lineStop) |i| {
        std.debug.print("{x:0>2} ", .{i});
    }
    std.debug.print("\n", .{});

    // main file read loop
    // in order to achieve true hexdump i need to
    // create a string and populate it with
    // possible printable characters

    var line: [lineStop]u8 = [_]u8{'.'} ** lineStop;
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
                std.debug.print("| {s}\n", .{line});
                line = [_]u8{'.'} ** lineStop;
            }

            // print the start of a new line and its offest
            std.debug.print("{x:0>8}: ", .{i});
            // clear the printable line
        }

        // if char is printable add it to the end string
        line[i % lineStop] = printable(char) catch '.';

        // print a char hex
        std.debug.print("{x:0>2} ", .{char});

        if (i == fileSize - 1) {
            for ((i % lineStop)..lineStop - 1) |_| {
                std.debug.print("   ", .{});
            }
            std.debug.print("| {s}\n", .{line});
        }
    }
}

fn printable(char: u8) !u8 {
    // if char in range return char
    // else return error
    if (char > 31 and char != 127) return char;
    return printError.notPrintable;
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
