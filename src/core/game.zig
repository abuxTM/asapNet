const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

const Server = @import("../networking/server.zig");

// Fields
// ================================
const Self = @This();
window: ?*c.SDL_Window = null,
renderer: ?*c.SDL_Renderer = null,
server: Server,
is_running: bool = true,
alloc: std.mem.Allocator,

/// Initialize Main Game
/// ================================
pub fn init(alloc: std.mem.Allocator) !Self {
    // Initialize SDL3
    // ======================================
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return error.SDLInitFailed;
    errdefer c.SDL_Quit();

    var window: ?*c.SDL_Window = null;
    var renderer: ?*c.SDL_Renderer = null;

    // Create New Window & Renderer
    // ======================================
    if (!c.SDL_CreateWindowAndRenderer(
        "A$AP LVL",
        800,
        600,
        0,
        &window,
        &renderer,
    )) return error.SDLCoreFailed;

    // Handle On Error
    // ======================================
    errdefer c.SDL_DestroyRenderer(renderer);
    errdefer c.SDL_DestroyWindow(window);

    // Init Server
    // ================================
    const server: Server = try .init(&.{}, alloc);

    var self: Self = .{
        .window = window,
        .renderer = renderer,
        .server = server,
        .alloc = alloc,
    };

    try self.run();

    return self;
}

/// Clean Everything Up
/// ================================
pub fn deinit(self: *Self) void {
    self.server.deinit();
    c.SDL_DestroyRenderer(self.renderer);
    c.SDL_DestroyWindow(self.window);
    c.SDL_Quit();
}

/// Run Main Game Loop
/// ================================
fn run(self: *Self) !void {
    while (self.is_running) {
        try self.pollEvents();
        try self.draw();
    }
}

/// Draw Game Objects
/// ================================
fn draw(self: *Self) !void {
    _ = c.SDL_SetRenderDrawColor(self.renderer, 3, 7, 18, 255);
    _ = c.SDL_RenderClear(self.renderer);
    defer _ = c.SDL_RenderPresent(self.renderer);

    // FIX: This Will Hang The Program On Exit
    var buf: [100]u8 = undefined;
    const fmt = try std.fmt.bufPrintZ(&buf, "Server: {s}", .{@tagName(self.server.state)[0..]});
    _ = c.SDL_SetRenderDrawColor(self.renderer, 200, 200, 200, 255);
    _ = c.SDL_RenderDebugTextFormat(self.renderer, 20, 20, fmt);
}

/// Process User Events
/// ================================
fn pollEvents(self: *Self) !void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        switch (event.type) {
            c.SDL_EVENT_QUIT => self.is_running = false,
            else => {},
        }

        if (event.key.scancode == c.SDL_SCANCODE_O) {
            if (self.server.state == .None)
                try self.server.start();
        }
    }
}
