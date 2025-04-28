const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

// Fields
// ================================
const Self = @This();
window: ?*c.SDL_Window = null,
renderer: ?*c.SDL_Renderer = null,
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

    var self: Self = .{
        .window = window,
        .renderer = renderer,
        .alloc = alloc,
    };

    try self.run();

    return self;
}

/// Clean Everything Up
/// ================================
pub fn deinit(self: *Self) void {
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
    }
}
