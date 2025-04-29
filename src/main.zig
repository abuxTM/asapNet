const std = @import("std");
const c = @cImport({
    @cInclude("enet/enet.h");
});

const Server = @import("networking/server.zig");
const Client = @import("networking/client.zig");
const Game = @import("core/game.zig");

pub fn main() !void {
    // Create Allocator
    // ================================
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Init ENet
    // ================================
    if (c.enet_initialize() != 0) return error.ENetFailedToInit;
    defer c.enet_deinitialize();

    // Init Client
    // ================================
    var client: Client = try .init(alloc);
    defer client.deinit();
    try client.connect("localhost", 7777);

    // Init Game
    // ================================
    var game: Game = try .init(alloc);
    defer game.deinit();
}
