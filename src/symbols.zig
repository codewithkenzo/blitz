//! Symbol resolution over an AST tree.
//!
//! Landing in ticket d1o-kjdk. Placeholder for now.

const std = @import("std");

pub const ResolveError = error{
    SymbolNotFound,
    AmbiguousSymbol,
};

test "symbols module placeholder" {
    _ = ResolveError;
}
