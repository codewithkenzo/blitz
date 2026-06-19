import assert from "node:assert/strict";
import { exactChangedSpan, isMinimalStructuralDecline } from "./true-streak.ts";

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

let classCBefore = "";
for (let i = 1; i <= 10; i++)
	classCBefore += `export function node${i}(value: number): number {\n  return value + ${i};\n}\n\n`;
const classCAfterFirst = classCBefore.replace(
	"export function node1(value: number): number {\n  return value + 1;\n}",
	"export function node1(value: number): number {\n  return value * 2;\n}",
);

assert.deepEqual(
	exactChangedSpan(classCBefore, classCAfterFirst),
	{ oldText: "+ 1;", newText: "* 2;" },
	"Class C optimized core span must include right boundary so '+ 1' does not also match '+ 10'",
);
