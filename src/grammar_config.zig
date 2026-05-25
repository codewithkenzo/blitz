const std = @import("std");
const bindings = @import("tree_sitter/bindings.zig");

pub const GrammarConfig = struct {
    language: bindings.Language,
    name: []const u8,
    extensions: []const []const u8,
    comment_styles: []const []const u8,
    declaration_kinds: []const []const u8,
    body_kinds: []const []const u8,
    name_fields: []const []const u8,
    brace_body: bool,
};

const declaration_kinds = [_][]const u8{
    "function_declaration",
    "function_definition",
    "function_item",
    "method_declaration",
    "method_definition",
    "class_declaration",
    "class_definition",
    "impl_item",
    "struct_item",
    "enum_item",
    "interface_declaration",
    "type_alias_declaration",
    "variable_declarator",
};

const body_kinds = [_][]const u8{
    "statement_block",
    "block",
    "class_body",
    "declaration_list",
};

const typescript_comment_styles = [_][]const u8{ "//", "/*" };
const python_comment_styles = [_][]const u8{"#"};
const name_fields = [_][]const u8{"name"};
const no_comment_styles = [_][]const u8{};
const no_kinds = [_][]const u8{};

const configs = [_]GrammarConfig{
    .{ .language = .rust, .name = "rust", .extensions = &.{".rs"}, .comment_styles = &typescript_comment_styles, .declaration_kinds = &declaration_kinds, .body_kinds = &body_kinds, .name_fields = &name_fields, .brace_body = true },
    .{ .language = .typescript, .name = "typescript", .extensions = &.{".ts"}, .comment_styles = &typescript_comment_styles, .declaration_kinds = &declaration_kinds, .body_kinds = &body_kinds, .name_fields = &name_fields, .brace_body = true },
    .{ .language = .tsx, .name = "tsx", .extensions = &.{".tsx"}, .comment_styles = &typescript_comment_styles, .declaration_kinds = &declaration_kinds, .body_kinds = &body_kinds, .name_fields = &name_fields, .brace_body = true },
    .{ .language = .python, .name = "python", .extensions = &.{".py"}, .comment_styles = &python_comment_styles, .declaration_kinds = &declaration_kinds, .body_kinds = &body_kinds, .name_fields = &name_fields, .brace_body = false },
    .{ .language = .go, .name = "go", .extensions = &.{".go"}, .comment_styles = &typescript_comment_styles, .declaration_kinds = &declaration_kinds, .body_kinds = &body_kinds, .name_fields = &name_fields, .brace_body = true },
    .{ .language = .json, .name = "json", .extensions = &.{".json"}, .comment_styles = &no_comment_styles, .declaration_kinds = &no_kinds, .body_kinds = &no_kinds, .name_fields = &no_kinds, .brace_body = true },
    .{ .language = .jsonc, .name = "jsonc", .extensions = &.{".jsonc"}, .comment_styles = &typescript_comment_styles, .declaration_kinds = &no_kinds, .body_kinds = &no_kinds, .name_fields = &no_kinds, .brace_body = true },
    .{ .language = .yaml, .name = "yaml", .extensions = &.{ ".yaml", ".yml" }, .comment_styles = &python_comment_styles, .declaration_kinds = &no_kinds, .body_kinds = &no_kinds, .name_fields = &no_kinds, .brace_body = false },
    .{ .language = .toml, .name = "toml", .extensions = &.{".toml"}, .comment_styles = &python_comment_styles, .declaration_kinds = &no_kinds, .body_kinds = &no_kinds, .name_fields = &no_kinds, .brace_body = false },
    .{ .language = .markdown, .name = "markdown", .extensions = &.{ ".md", ".markdown" }, .comment_styles = &no_comment_styles, .declaration_kinds = &no_kinds, .body_kinds = &no_kinds, .name_fields = &no_kinds, .brace_body = false },
    .{ .language = .html, .name = "html", .extensions = &.{ ".html", ".htm" }, .comment_styles = &.{"<!--"}, .declaration_kinds = &no_kinds, .body_kinds = &no_kinds, .name_fields = &no_kinds, .brace_body = true },
    .{ .language = .css, .name = "css", .extensions = &.{".css"}, .comment_styles = &.{"/*"}, .declaration_kinds = &no_kinds, .body_kinds = &no_kinds, .name_fields = &no_kinds, .brace_body = true },
};

pub fn languageForExtension(ext: []const u8) ?bindings.Language {
    if (std.ascii.eqlIgnoreCase(ext, ".rs")) return .rust;
    if (std.ascii.eqlIgnoreCase(ext, ".ts")) return .typescript;
    if (std.ascii.eqlIgnoreCase(ext, ".tsx")) return .tsx;
    if (std.ascii.eqlIgnoreCase(ext, ".py")) return .python;
    if (std.ascii.eqlIgnoreCase(ext, ".go")) return .go;
    if (std.ascii.eqlIgnoreCase(ext, ".json")) return .json;
    if (std.ascii.eqlIgnoreCase(ext, ".jsonc")) return .jsonc;
    if (std.ascii.eqlIgnoreCase(ext, ".yaml") or std.ascii.eqlIgnoreCase(ext, ".yml")) return .yaml;
    if (std.ascii.eqlIgnoreCase(ext, ".toml")) return .toml;
    if (std.ascii.eqlIgnoreCase(ext, ".md") or std.ascii.eqlIgnoreCase(ext, ".markdown")) return .markdown;
    if (std.ascii.eqlIgnoreCase(ext, ".html") or std.ascii.eqlIgnoreCase(ext, ".htm")) return .html;
    if (std.ascii.eqlIgnoreCase(ext, ".css")) return .css;
    return null;
}

pub fn languageName(lang: bindings.Language) []const u8 {
    return configForLanguage(lang).name;
}

pub fn commentStylesFor(language: bindings.Language) []const []const u8 {
    return configForLanguage(language).comment_styles;
}

pub fn declarationKinds() []const []const u8 {
    return &declaration_kinds;
}

pub fn bodyKinds() []const []const u8 {
    return &body_kinds;
}

pub fn isDeclarationKind(kind: []const u8) bool {
    inline for (declaration_kinds) |candidate| {
        if (std.mem.eql(u8, kind, candidate)) return true;
    }
    return false;
}

pub fn isBodyKind(kind: []const u8) bool {
    inline for (body_kinds) |candidate| {
        if (std.mem.eql(u8, kind, candidate)) return true;
    }
    return false;
}

pub fn nameFieldForKind(kind: []const u8) ?[]const u8 {
    return if (isDeclarationKind(kind)) name_fields[0] else null;
}

pub fn usesBraceBodies(language: bindings.Language) bool {
    return configForLanguage(language).brace_body;
}

pub fn supportsTryCatch(language: bindings.Language) bool {
    return language == .typescript or language == .tsx;
}

pub fn returnStatementSuffix(language: bindings.Language) []const u8 {
    return if (language == .python) "" else ";";
}

pub fn usesPythonBodies(language: bindings.Language) bool {
    return language == .python;
}

pub fn configForLanguage(language: bindings.Language) GrammarConfig {
    inline for (configs) |config| {
        if (config.language == language) return config;
    }
    return configs[0];
}

test "grammar config maps jsonc extension" {
    try std.testing.expectEqual(bindings.Language.jsonc, languageForExtension(".jsonc").?);

    const config = configForLanguage(.jsonc);
    try std.testing.expectEqualStrings("jsonc", config.name);
    try std.testing.expectEqual(@as(usize, 1), config.extensions.len);
    try std.testing.expectEqualStrings(".jsonc", config.extensions[0]);
}
