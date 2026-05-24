const ast = @import("ast.zig");

pub const ResolveError = ast.ResolveError;
pub const ByteRange = ast.ByteRange;
pub const findEditableSymbolNode = ast.findEditableSymbolNode;
pub const resolveEditableSymbol = ast.resolveEditableSymbol;
pub const countEditableSymbolMatches = ast.countEditableSymbolMatches;
pub const findBodyNode = ast.findBodyNode;
pub const bodyRangeFor = ast.bodyRangeFor;
pub const replacementRangeFor = ast.replacementRangeFor;
