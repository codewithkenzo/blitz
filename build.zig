//! blitz build.zig — Zig 0.16 stable.
//!
//! Scaffold build. tree-sitter static link + grammar vendoring is ticket d1o-qphx.
//! Current state: compiles a CLI stub that prints --help / --version.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---- root module ----
    const root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ---- exe ----
    const exe = b.addExecutable(.{
        .name = "blitz",
        .root_module = root,
    });
    b.installArtifact(exe);

    // ---- run step ----
    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Run blitz");
    run_step.dependOn(&run_exe.step);

    // ---- tests ----
    const tests = b.addTest(.{
        .root_module = root,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // ---- TODO(ticket d1o-qphx): link vendored tree-sitter + grammars ----
    //
    // const ts_lib = b.addLibrary(.{
    //     .name = "tree-sitter",
    //     .root_module = b.createModule(.{ .target = target, .optimize = optimize }),
    //     .linkage = .static,
    // });
    // ts_lib.root_module.addCSourceFiles(.{
    //     .root = b.path("third_party/tree-sitter/lib/src"),
    //     .files = &.{"lib.c"},
    //     .flags = &.{"-std=c11"},
    // });
    // ts_lib.root_module.addIncludePath(b.path("third_party/tree-sitter/lib/include"));
    // ts_lib.root_module.link_libc = true;
    //
    // const grammars = [_][]const u8{ "rust", "typescript", "tsx", "python", "go" };
    // for (grammars) |g| {
    //     const path = b.fmt("grammars/tree-sitter-{s}/src/parser.c", .{g});
    //     ts_lib.root_module.addCSourceFile(.{
    //         .file = b.path(path),
    //         .flags = &.{"-std=c11"},
    //     });
    // }
    //
    // root.linkLibrary(ts_lib);
    // root.addIncludePath(b.path("third_party/tree-sitter/lib/include"));
}
