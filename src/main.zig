const std = @import("std");
const testing = std.testing;

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

    std.debug.print("{x:0>8}: ", .{fileSize});
    for (0..lineStop) |i| {
        std.debug.print("{x:0>2} ", .{i});
    }
    std.debug.print("\n", .{});

    for (0..fileSize) |i| {
        const char = buffer[i];

        if (i % lineStop == 0) {
            if (i != 0x0) std.debug.print("\n", .{});
            std.debug.print("{x:0>8}: ", .{i});
        }
        std.debug.print("{x:0>2} ", .{char});
    }
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
