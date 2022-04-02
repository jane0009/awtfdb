const std = @import("std");
const deps = @import("./deps.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("awtfdb-manage", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    deps.addAllTo(exe);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    deps.addAllTo(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    const watcher_exe = b.addExecutable("awtfdb-watcher", "src/rename_watcher_main.zig");
    watcher_exe.setTarget(target);
    watcher_exe.setBuildMode(mode);
    watcher_exe.install();
    deps.addAllTo(watcher_exe);

    const include_exe = b.addExecutable("ainclude", "src/include_main.zig");
    include_exe.setTarget(target);
    include_exe.setBuildMode(mode);
    include_exe.install();
    deps.addAllTo(include_exe);

    const find_exe = b.addExecutable("afind", "src/find_main.zig");
    find_exe.setTarget(target);
    find_exe.setBuildMode(mode);
    find_exe.install();
    deps.addAllTo(find_exe);

    const ls_exe = b.addExecutable("als", "src/ls_main.zig");
    ls_exe.setTarget(target);
    ls_exe.setBuildMode(mode);
    ls_exe.install();
    deps.addAllTo(ls_exe);

    // const rm_exe = b.addExecutable("arm", "src/rm_main.zig");
    // rm_exe.setTarget(target);
    // rm_exe.setBuildMode(mode);
    // rm_exe.install();
    // deps.addAllTo(rm_exe);
}
