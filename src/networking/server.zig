const std = @import("std");
const c = @cImport({
    @cInclude("enet/enet.h");
});

const Packet = @import("packet.zig");
const Player = @import("player.zig");

pub const Config = struct {
    ip: []const u8 = "localhost",
    port: u16 = 7777,
    max_clients: usize = 6,
    channels: usize = 2,
};

// Fields
// ================================
const Self = @This();
host: *c.ENetHost,
run_thread: ?std.Thread = null,
mutex: std.Thread.Mutex = .{},
is_running: bool = true,
players: std.ArrayList(Player),
alloc: std.mem.Allocator,

state: enum {
    Running,
    Stopping,
    None,
},

/// Initialize Server Component
/// ================================
pub fn init(config: *const Config, alloc: std.mem.Allocator) !Self {
    // Configure Address
    // ================================
    var address: c.ENetAddress = .{ .port = config.port };
    if (c.enet_address_set_host(&address, config.ip.ptr) != 0) return error.MaybeWrongIp;

    // Create & Setup Host
    // ================================
    const host: ?*c.ENetHost = c.enet_host_create(&address, config.max_clients, config.channels, 0, 0) orelse {
        return error.HostCreationFailed;
    };

    std.debug.print(
        "[SERVER] Started At [{s}:{}]\n",
        .{ config.ip, config.port },
    );

    return .{
        .host = host.?,
        .players = .init(alloc),
        .state = .None,
        .alloc = alloc,
    };
}

/// Cleanup Resources
/// ================================
pub fn deinit(self: *Self) void {
    self.stop();
    c.enet_host_destroy(self.host);
    self.players.deinit();
    self.state = .None;
}

/// Listen For Client On New Thread
/// ================================
pub fn start(self: *Self) !void {
    self.state = .Running;
    self.run_thread = try std.Thread.spawn(.{}, eventService, .{self});
}

/// Stop The Server
/// ================================
fn stop(self: *Self) void {
    if (self.run_thread) |t| {
        self.state = .Stopping;
        self.mutex.lock();
        self.is_running = false;
        self.mutex.unlock();
        t.join();
    }
}

/// Event Handler
/// ================================
fn eventService(self: *Self) !void {
    while (true) {
        // Check Current State
        // ================================
        self.mutex.lock();
        const running = self.is_running;
        self.mutex.unlock();

        // Break On Exit
        // ================================
        if (!running) break;

        // Handle Events
        // ================================
        var event: c.ENetEvent = undefined;
        while (c.enet_host_service(self.host, &event, 1000) > 0) {
            switch (event.type) {
                c.ENET_EVENT_TYPE_CONNECT => try self.onConnect(&event),
                c.ENET_EVENT_TYPE_DISCONNECT => try self.onDisconnect(&event),
                c.ENET_EVENT_TYPE_RECEIVE => try self.onReceive(&event),
                else => {},
            }
        }
    }
}

/// Handle Client Connection
/// ================================
fn onConnect(self: *Self, event: *c.ENetEvent) !void {
    std.debug.print(
        "[SERVER] New Client From [{}:{}]\n",
        .{
            event.peer.*.address.host,
            event.peer.*.address.port,
        },
    );

    const player = try self.alloc.create(Player);
    defer self.alloc.destroy(player);

    player.* = .{
        .state = .{ .pending = .{} },
        .peer = event.peer,
    };

    event.peer.*.data = player;

    try Packet.send(
        .AUTH_REQUEST,
        &.{ .peer = event.peer },
        self.alloc,
    );
}

/// Handle Client Disconnection
/// ================================
fn onDisconnect(self: *Self, event: *c.ENetEvent) !void {
    _ = self;

    const player = @as(*Player, @ptrCast(@alignCast(event.peer.*.data)));
    std.debug.print("[SERVER] {}:{s} Has Disconnected\n", .{
        player.state.connected.id,
        player.state.connected.username,
    });

    event.peer.*.data = null;
}

/// Handle Client's Packet's
/// ================================
fn onReceive(self: *Self, event: *c.ENetEvent) !void {
    // Local Fields
    // ================================
    const packet_data = event.packet.*.data;
    const packet_len = event.packet.*.dataLength;
    defer c.enet_packet_destroy(event.packet);

    // Log Received Packet Type
    // ================================
    std.debug.print(
        "[SERVER] Received {s} Packet From Client\n",
        .{packet_data[0..]},
    );

    const packet_type_data = try Packet.deserialize(
        Packet.PacketData,
        packet_data[0..packet_len],
        self.alloc,
    );

    switch (packet_type_data) {
        .AUTH_RESPONSE => {
            // Create New Player Data Info
            // ================================
            const player = try self.alloc.create(Player);
            defer self.alloc.destroy(player);

            // Asign New Data
            // ================================
            player.* = .{
                .state = .{
                    .connected = .{
                        .id = 0,
                        .username = packet_type_data.AUTH_RESPONSE.username,
                        .pos = .{ 0, 0 },
                    },
                },
                .peer = event.peer,
            };
            event.peer.*.data = player;

            // Send Join Packet
            // ================================
            try Packet.send(
                .{
                    .PLAYER_JOIN = .{
                        .id = player.state.connected.id,
                        .username = player.state.connected.username,
                        .pos = player.state.connected.pos,
                    },
                },
                &.{ .host = self.host, .broadcast = true },
                self.alloc,
            );
        },
        else => {
            std.debug.print("[CLIENT] Unhandled Packet Type: {s}\n", .{@tagName(packet_type_data)});
        },
    }
}
