// src/cli.zig
const std = @import("std");
const zli = @import("zli");

const rootOpts: zli.CommandOptions = .{
    .name = "evtdb",
    .description = "Event Log Database",
    .version = .{ .major = 0, .minor = 0, .patch = 2, .pre = null, .build = null },
};

const versionOpts: zli.CommandOptions = .{
    .name = "version",
    .shortcut = "v",
    .description = "Show version",
};

const serverOpts: zli.CommandOptions = .{
    .name = "server",
    .description = "Start evtdb server",
};

const serverPortFlag: zli.Flag = .{
    .name = "port",
    .shortcut = "p",
    .description = "Port of the evtdb server",
    .type = .Int,
    .default_value = .{ .Int = 1984 },
};

pub fn build(opts: zli.InitOptions) !*zli.Command {
    const rootCmd = try zli.Command.init(opts, rootOpts, showHelp);
    const versionCmd = try zli.Command.init(opts, versionOpts, showVersion);
    const serverCmd = try zli.Command.init(opts, serverOpts, startServer);

    try serverCmd.addFlag(serverPortFlag);

    try rootCmd.addCommand(versionCmd);
    try rootCmd.addCommand(serverCmd);
    return rootCmd;
}

fn showHelp(ctx: zli.CommandContext) !void {
    try ctx.command.printHelp();
}

fn showVersion(ctx: zli.CommandContext) !void {
    try ctx.root.printVersion();
}

fn startServer(ctx: zli.CommandContext) !void {
    _ = ctx;
}
