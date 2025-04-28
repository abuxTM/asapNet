const std = @import("std");
const c = @cImport({
    @cInclude("enet/enet.h");
});

const Packet = @import("packet.zig");

// Fields
// ================================
const Self = @This();
handle: *c.ENetHost,
peer: ?*c.ENetPeer = null,
run_thread: ?std.Thread = null,
mutex: std.Thread.Mutex = .{},
is_running: bool = true,
alloc: std.mem.Allocator,

/// Initialize Server Component
/// ================================
pub fn init(alloc: std.mem.Allocator) !Self {
    // Create & Setup Host
    // ================================
    const handle: ?*c.ENetHost = c.enet_host_create(null, 1, 2, 0, 0) orelse {
        return error.HostCreationFailed;
    };

    return .{
        .handle = handle.?,
        .alloc = alloc,
    };
}

/// Cleanup Resources
/// ================================
pub fn deinit(self: *Self) void {
    if (self.peer) |p| {
        c.enet_peer_disconnect(p, 0);
    }
    self.stop();
    c.enet_host_destroy(self.handle);
}

/// Connect To A Host
/// ================================
pub fn connect(self: *Self, ip: []const u8, port: u16) !void {
    // Configure Address
    // ================================
    var address: c.ENetAddress = .{ .port = port };
    if (c.enet_address_set_host(&address, ip.ptr) != 0) return error.MaybeWrongIp;

    self.peer = c.enet_host_connect(self.handle, &address, 2, 0) orelse {
        return error.NoPeersAvailable;
    };

    try self.start();

    std.debug.print(
        "[CLIENT] Connecting To [{s}:{}]\n",
        .{ ip, port },
    );
}

/// New Thread
/// ================================
fn start(self: *Self) !void {
    self.run_thread = try std.Thread.spawn(.{}, eventService, .{self});
}

/// Stop The Client
/// ================================
fn stop(self: *Self) void {
    if (self.run_thread) |t| {
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
        while (c.enet_host_service(self.handle, &event, 1000) > 0) {
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
    _ = self;
    _ = event;
}

/// Handle Client Disconnection
/// ================================
fn onDisconnect(self: *Self, event: *c.ENetEvent) !void {
    _ = self;
    _ = event;
}

/// Handle Client's Packet's
/// ================================
fn onReceive(self: *Self, event: *c.ENetEvent) !void {
    // Local Fields
    // ================================
    const packet_data = event.packet.*.data;
    const packet_len = event.packet.*.dataLength;
    defer c.enet_packet_destroy(event.packet);

    // Check If Packet Is Valid
    // ================================
    if (packet_len < 1) {
        std.debug.print("[CLIENT] Invalid Packet Length: {}\n", .{packet_len});
        return error.InvalidPacket;
    }

    // Extract Packet Type
    // ================================
    const packet_type = std.meta.intToEnum(Packet.PacketType, packet_data[0]) catch |err| {
        std.debug.print("[CLIENT] Unknown Packet Type: 0x{X}\n", .{packet_data[0]});
        return err;
    };

    // Log Received Packet Type
    // ================================
    std.debug.print("[CLIENT] Received {s} Packet From Server\n", .{@tagName(packet_type)});

    // Handle Packet
    // ================================
    switch (packet_type) {
        .AUTH_REQUEST => {
            try Packet.send(
                .AUTH_RESPONSE,
                &.{ .peer = event.peer },
                self.alloc,
            );
        },
        else => {
            std.debug.print("[CLIENT] Unhandled Packet Type: {s}\n", .{@tagName(packet_type)});
        },
    }
}
