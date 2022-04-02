const std = @import("std");
const sqlite = @import("sqlite");
const manage_main = @import("main.zig");
const libpcre = @import("libpcre");
const Context = manage_main.Context;

const log = std.log.scoped(.atags);

const VERSION = "0.0.1";
const HELPTEXT =
    \\ atags: manage your tags
    \\
    \\ usage:
    \\ 	atags action [arguments...]
    \\
    \\ options:
    \\ 	-h				prints this help and exits
    \\ 	-V				prints version and exits
    \\
    \\ examples:
    \\ 	atags create tag
    \\ 	atags create --tag-core lkdjfalskjg tag
    \\ 	atags remove tag
    \\ 	atags remove --tag-core dslkjfsldkjf
    \\ 	atags search tag
;

const ActionConfig = union(enum) {
    //Create: CreateAction.Config,
    //Remove: RemoveAction.Config,
    Search: SearchAction.Config,
};

const CreateAction = struct {
    pub const Config = struct {
        tag_core: ?[]const u8 = null,
        tag: ?[]const u8 = null,
    };
    pub fn processArgs(args_it: *std.process.ArgIterator) !ActionConfig {
        _ = args_it;
        std.debug.todo("todo create");
    }
};

const RemoveAction = struct {
    pub const Config = struct {
        tag_core: ?[]const u8 = null,
        tag: ?[]const u8 = null,
    };
    pub fn processArgs(args_it: *std.process.ArgIterator) !ActionConfig {
        _ = args_it;
        std.debug.todo("todo remove");
    }
};

const SearchAction = struct {
    pub const Config = struct {
        query: ?[]const u8 = null,
    };

    pub fn processArgs(args_it: *std.process.ArgIterator) !ActionConfig {
        var config = Config{};
        config.query = args_it.next() orelse return error.MissingQuery;
        return ActionConfig{ .Search = config };
    }

    ctx: *Context,
    config: Config,

    const Self = @This();

    pub fn init(ctx: *Context, config: Config) !Self {
        return Self{ .ctx = ctx, .config = config };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn run(self: *Self) !void {
        var stdout = std.io.getStdOut().writer();

        var stmt = try self.ctx.db.?.prepare(
            \\ select tag_text, tag_language, core_hash, hashes.hash_data
            \\ from tag_names
            \\ join hashes
            \\  on hashes.id = tag_names.core_hash
            \\ where tag_text LIKE '%' || ? || '%'
        );
        defer stmt.deinit();

        var tag_names = try stmt.all(
            struct {
                tag_text: []const u8,
                tag_language: []const u8,
                core_hash: i64,
                hash_data: sqlite.Blob,
            },
            self.ctx.allocator,
            .{},
            .{self.config.query.?},
        );

        defer {
            for (tag_names) |tag| {
                self.ctx.allocator.free(tag.tag_text);
                self.ctx.allocator.free(tag.tag_language);
                self.ctx.allocator.free(tag.hash_data.data);
            }
            self.ctx.allocator.free(tag_names);
        }

        for (tag_names) |tag_name| {
            const fake_hash = Context.HashWithBlob{
                .id = tag_name.core_hash,
                .hash_data = tag_name.hash_data,
            };
            var related_tags = try self.ctx.fetchTagsFromCore(
                self.ctx.allocator,
                fake_hash.toRealHash(),
            );
            defer related_tags.deinit();

            const full_tag_core = related_tags.items[0].core;
            try stdout.print("{s}", .{full_tag_core});
            for (related_tags.items) |tag| {
                try stdout.print(" '{s}'", .{tag});
            }
            try stdout.print("\n", .{});
        }
    }
};

pub fn main() anyerror!void {
    const rc = sqlite.c.sqlite3_config(sqlite.c.SQLITE_CONFIG_LOG, manage_main.sqliteLog, @as(?*anyopaque, null));
    if (rc != sqlite.c.SQLITE_OK) {
        std.log.err("failed to configure: {d} '{s}'", .{
            rc, sqlite.c.sqlite3_errstr(rc),
        });
        return error.ConfigFail;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var args_it = std.process.args();
    _ = args_it.skip();

    const Args = struct {
        help: bool = false,
        version: bool = false,
        action_config: ?ActionConfig = null,
    };

    var given_args = Args{};

    while (args_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h")) {
            given_args.help = true;
        } else if (std.mem.eql(u8, arg, "-V")) {
            given_args.version = true;
        } else {
            if (std.mem.eql(u8, arg, "search")) {
                given_args.action_config = try SearchAction.processArgs(&args_it);
            }
        }
    }

    if (given_args.help) {
        std.debug.print(HELPTEXT, .{});
        return;
    } else if (given_args.version) {
        std.debug.print("ainclude {s}\n", .{VERSION});
        return;
    }

    if (given_args.action_config == null) {
        std.log.err("action is a required argument", .{});
        return error.MissingAction;
    }
    const action_config = given_args.action_config.?;

    var ctx = Context{
        .home_path = null,
        .args_it = undefined,
        .stdout = undefined,
        .db = null,
        .allocator = allocator,
    };
    defer ctx.deinit();

    try ctx.loadDatabase(.{});

    switch (action_config) {
        .Search => |search_config| {
            var self = try SearchAction.init(&ctx, search_config);
            defer self.deinit();
            try self.run();
        },
    }
}
