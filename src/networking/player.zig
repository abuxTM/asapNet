const c = @cImport({
    @cInclude("enet/enet.h");
});

state: union(enum) {
    pending: struct {},
    connected: struct {
        id: u32,
        username: []const u8,
        pos: [2]f32,
    },
},

peer: *c.ENetPeer,
