import assert from "node:assert/strict";
import { isMinimalStructuralDecline } from "./true-streak.ts";

const declineText =
	"decline op=rb reason=unsupported_structural_op_minimal no_mutation=true use core/apply_patch or PI_BLITZ_TOOL_PROFILE=structural";

assert.equal(
	isMinimalStructuralDecline("blitz-edit", "class-c-structural-10", [
		{ toolName: "blitz_edit", text: declineText },
	]),
	true,
	"Class C blitz_edit rb decline should classify as explicit no-mutation decline",
);

assert.equal(
	isMinimalStructuralDecline("blitz-edit", "tiny-10", [
		{ toolName: "blitz_edit", text: declineText },
	]),
	false,
	"non-Class-C rows must not be classified as structural decline",
);

assert.equal(
	isMinimalStructuralDecline("blitz-edit", "class-c-structural-10", [
		{ toolName: "edit", text: declineText },
	]),
	false,
	"non-blitz_edit tool result must not be classified as structural decline",
);
