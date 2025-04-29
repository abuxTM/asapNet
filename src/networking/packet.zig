const std = @import("std");
const c = @cImport({
    @cInclude("enet/enet.h");
});

// TODO: Add Bidirectional Stuff e.g Chat

pub const PacketType = enum(u8) {
    // Auth & Connection
    // ================================
    AUTH_REQUEST, // Server -> Client: "Send Ur Creds Pls (Username)"
    AUTH_RESPONSE, // Client -> Server: Username, etc
    AUTH_SUCCESS, // Server -> Client: Login Approved
    AUTH_FAILED, // Server -> Client: Login Rejected
    DISCONNECT, // Bidirectional: Disconnect

    // Game State
    // ================================
    PLAYER_JOIN, // Server -> All: New Player Data
    PLAYER_LEAVE, // Server -> All: Player Left :(
    PLAYER_STATE, // Client -> Server: Position/Input Update's
    WORLD_STATE, // Server -> All: World Sync With Clients

    // Entity Managment
    // ================================
    SPAWN_ENTITY, // Server -> All: New Entity (Enemy, Item, Projectile, etc)
    DESTROY_ENTITY, // Server -> All: Remove Entity :0
    ENTITY_UPDATE, // Server -> All: Entity State (Movement, Health, etc)
};

// TODO: Why This No Use?
pub const PacketData = union(PacketType) {
    // Auth & Connection
    // ================================
    AUTH_REQUEST: void,
    AUTH_RESPONSE: struct {
        username: []const u8,
    },
    AUTH_SUCCESS: struct {
        player_id: u32,
        spawn_pos: [2]f32,
    },
    AUTH_FAILED: struct {
        reason: []const u8,
    },
    DISCONNECT: void,

    // Game State
    // ================================
    PLAYER_JOIN: struct {
        id: u32,
        username: []const u8,
        pos: [2]f32,
    },
    PLAYER_LEAVE: u32, // Player ID
    PLAYER_STATE: struct {
        input_flags: u16, // Bitmask (UP=0x1, DOWN=0x2, etc)
        pos: [2]f32,
    },
    WORLD_STATE: struct {
        time: u64, // Game clock
        entities: []const u8,
    },

    // Entity Managment
    // ================================
    SPAWN_ENTITY: struct {}, // TODO:
    DESTROY_ENTITY: struct { id: u32 },
    ENTITY_UPDATE: struct {
        id: u32,
        pos: [3]f32,
        yes: bool,
    },
};

pub const SendConfig = struct {
    peer: ?*c.ENetPeer = null,
    host: ?*c.ENetHost = null,
    reliable: bool = true,
    broadcast: bool = false,
    channel: u8 = 0,
};

/// TODO: Remove This
/// Send New Packet
/// ================================
pub fn sendType(
    packet_type: PacketType,
    config: *const SendConfig,
    alloc: std.mem.Allocator,
) !void {
    const buffer = try alloc.alloc(u8, 1);
    defer alloc.free(buffer);
    buffer[0] = @intFromEnum(packet_type);

    // Create New Packet
    // ================================
    const packet: *c.ENetPacket = c.enet_packet_create(
        buffer.ptr,
        1,
        if (config.reliable) c.ENET_PACKET_FLAG_RELIABLE else c.ENET_PACKET_FLAG_UNSEQUENCED,
    );

    // Send Or Broadcast
    // ================================
    if (config.broadcast) {
        if (config.host) |host| {
            c.enet_host_broadcast(host, config.channel, packet);
        } else {
            std.debug.print("[NET] Error: Cannot broadcast - host is null\n", .{});
            return error.NullHost;
        }
    } else {
        if (config.peer) |peer| {
            if (c.enet_peer_send(peer, config.channel, packet) < 0) {
                return error.SendFailed;
            }
        } else {
            std.debug.print("[NET] Error: Cannot send - peer is null\n", .{});
            return error.NullPeer;
        }
    }

    // Force Delivery
    if (config.host) |host| {
        c.enet_host_flush(host);
    }
}

/// Send New Packet
/// ================================
pub fn send(
    data: PacketData,
    config: *const SendConfig,
    alloc: std.mem.Allocator,
) !void {
    var string = std.ArrayList(u8).init(alloc);
    defer string.deinit();
    try std.json.stringify(data, .{}, string.writer());

    // Create New Packet
    // ================================
    const packet: *c.ENetPacket = c.enet_packet_create(
        string.items.ptr,
        string.items.len,
        if (config.reliable) c.ENET_PACKET_FLAG_RELIABLE else c.ENET_PACKET_FLAG_UNSEQUENCED,
    );

    // Send Or Broadcast
    // ================================
    if (config.broadcast) {
        if (config.host) |host| {
            c.enet_host_broadcast(host, config.channel, packet);
        } else {
            std.debug.print("[NET] Error: Cannot broadcast - host is null\n", .{});
            return error.NullHost;
        }
    } else {
        if (config.peer) |peer| {
            if (c.enet_peer_send(peer, config.channel, packet) < 0) {
                return error.SendFailed;
            }
        } else {
            std.debug.print("[NET] Error: Cannot send - peer is null\n", .{});
            return error.NullPeer;
        }
    }

    // Force Delivery
    if (config.host) |host| {
        c.enet_host_flush(host);
    }
}

pub fn deserialize(comptime T: type, data: []const u8, alloc: std.mem.Allocator) !PacketData {
    const parsed = try std.json.parseFromSlice(T, alloc, data, .{});
    defer parsed.deinit();
    return parsed.value;
}
