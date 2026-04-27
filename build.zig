//! blitz build.zig — Zig 0.16 stable.
//!
//! Statically links the vendored tree-sitter runtime (third_party/tree-sitter/)
//! and the five vendored grammars under grammars/tree-sitter-<lang>/.

const std = @import("std");

const grammars = [_]Grammar{
    .{ .name = "rust", .has_scanner = true },
    .{ .name = "typescript", .has_scanner = true },
    .{ .name = "tsx", .has_scanner = true },
    .{ .name = "python", .has_scanner = true },
    .{ .name = "go", .has_scanner = false },
};

const Grammar = struct {
    name: []const u8,
    has_scanner: bool,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---- tree-sitter static library ----
    const ts_lib = b.addLibrary(.{
        .name = "tree-sitter",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });
    ts_lib.root_module.addCSourceFile(.{
        .file = b.path("third_party/tree-sitter/lib/src/lib.c"),
        .flags = &.{
            "-std=c11",
            "-fvisibility=hidden",
            // POSIX feature-test macro: makes le16toh, be16toh, fdopen visible.
            "-D_GNU_SOURCE",
            // tree-sitter ships large generated sources; quiet harmless warnings.
            "-Wno-unused-parameter",
            "-Wno-unused-function",
            "-Wno-unused-but-set-variable",
        },
    });
    ts_lib.root_module.addIncludePath(b.path("third_party/tree-sitter/lib/include"));
    ts_lib.root_module.addIncludePath(b.path("third_party/tree-sitter/lib/src"));

    // ---- grammar libs (one translation unit each) ----
    var grammar_libs: [grammars.len]*std.Build.Step.Compile = undefined;
    for (grammars, 0..) |g, idx| {
        const glib = b.addLibrary(.{
            .name = b.fmt("tree-sitter-{s}", .{g.name}),
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
            .linkage = .static,
        });
        const src_dir = b.fmt("grammars/tree-sitter-{s}/src", .{g.name});
        glib.root_module.addCSourceFile(.{
            .file = b.path(b.fmt("{s}/parser.c", .{src_dir})),
            .flags = &.{
                "-std=c11",
                "-fvisibility=hidden",
                "-Wno-unused-parameter",
                "-Wno-unused-function",
                "-Wno-unused-but-set-variable",
            },
        });
        if (g.has_scanner) {
            glib.root_module.addCSourceFile(.{
                .file = b.path(b.fmt("{s}/scanner.c", .{src_dir})),
                .flags = &.{
                    "-std=c11",
                    "-fvisibility=hidden",
                    "-Wno-unused-parameter",
                    "-Wno-unused-function",
                    "-Wno-unused-but-set-variable",
                },
            });
        }
        // Grammar local header (parser.h, alloc.h, array.h) lives in src/tree_sitter.
        glib.root_module.addIncludePath(b.path(src_dir));
        grammar_libs[idx] = glib;
    }

    // ---- root module for blitz exe + tests ----
    const root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Expose tree-sitter headers so bindings.zig can reference api.h shapes
    // through the Zig extern block without @cImport.
    root.addIncludePath(b.path("third_party/tree-sitter/lib/include"));
    root.linkLibrary(ts_lib);
    for (grammar_libs) |glib| root.linkLibrary(glib);

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
    const test_root = b.createModule(.{
        .root_source_file = b.path("src/test_all.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_root.addIncludePath(b.path("third_party/tree-sitter/lib/include"));
    test_root.linkLibrary(ts_lib);
    for (grammar_libs) |glib| test_root.linkLibrary(glib);

    const tests = b.addTest(.{
        .root_module = test_root,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
