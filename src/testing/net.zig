const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = error{
    ServerStartFailed,
};

pub const Config = struct {
    ip: []const u8 = "localhost",
    port: u16 = 7777,
    max_clients: usize = 6,
    channels: usize = 2,
};

/// Create New Comptime Known Type
/// =====================================
pub fn Network(comptime config: Config) type {
    return struct {
        // Fields
        // =====================================
        const Self = @This();

        /// Core: Init All Necessary Fields
        /// =====================================
        pub fn init(allocator: Allocator) Self {
            _ = allocator;
            return .{};
        }

        /// Core: Cleanup Resources
        /// =====================================
        pub fn deinit(self: *Self) void {
            _ = config;
            _ = self;
        }

        /// Type: Create New Server Type
        /// =====================================
        pub fn Server(comptime self: *const Self) type {
            return struct {
                pub fn start() void {
                    _ = self;
                }
            };
        }

        /// Type: Create New Server Type
        /// =====================================
        pub fn Client(comptime self: *const Self) type {
            return struct {
                pub fn connect() void {
                    _ = self;
                }
            };
        }
    };
}
