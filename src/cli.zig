// src/cli.zig
const std = @import("std");
const zli = @import("zli");

const rootOpts: zli.CommandOptions = .{
    .name = "evtdb",
    .description = "Event Log",
    .version = .{ .major = 0, .minor = 0, .patch = 2, .pre = null, .build = null },
};

const versionOpts: zli.CommandOptions = .{
    .name = "version",
    .shortcut = "v",
    .description = "Show version",
};

pub fn build(opts: zli.InitOptions) !*zli.Command {
    const root = try zli.Command.init(opts, rootOpts, showHelp);
    try root.addCommand(try zli.Command.init(opts, versionOpts, showVersion));
    return root;
}

fn showHelp(ctx: zli.CommandContext) !void {
    try ctx.command.printHelp();
}

fn showVersion(ctx: zli.CommandContext) !void {
    try ctx.root.printVersion();
}
