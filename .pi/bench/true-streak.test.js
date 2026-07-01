import assert from "node:assert/strict";
import {
	allEditTypesSafetyFixtures,
	allEditTypesSuccessScenario,
	exactChangedSpan,
	isMinimalStructuralDecline,
	resolveScenario,
} from "./true-streak.ts";

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

const sprintDSuccess = allEditTypesSuccessScenario();
const resolvedAllEditTypesGate = resolveScenario("all-edit-types-gate");
assert.equal(
	resolvedAllEditTypesGate.id,
	"all-edit-types-gate",
	"all-edit-types-gate request must emit matching scenario id",
);
assert.notEqual(
	resolvedAllEditTypesGate.id,
	"tiny-10",
	"all-edit-types-gate must not fall through to tiny-10",
);
assert.deepEqual(
	resolvedAllEditTypesGate.steps.map((step) => step.path),
	sprintDSuccess.steps.map((step) => step.path),
	"all-edit-types-gate resolver must use Sprint D success fixture paths",
);
assert.deepEqual(
	sprintDSuccess.steps.map((step) => step.id),
	[
		"e06-import-edit",
		"e07-rename-local-usage",
		"e10-wrap-try-catch",
		"e11-delete-range",
		"e12-append-section",
	],
	"Sprint D success rows must be concrete runnable paired fixtures, not placeholders",
);
for (const step of sprintDSuccess.steps) {
	assert.notEqual(
		step.before,
		step.after,
		`${step.id} must have expected output`,
	);
	assert.ok(step.before.length > 0, `${step.id} must define initial fixture`);
	assert.ok(step.after.length > 0, `${step.id} must define expected fixture`);
}

const structuralBefore = `export function alpha(value: number): number {\n  return value + 1;\n}\n\nexport function beta(): string {\n  return "new";\n}\n`;
const structuralAfter = `${structuralBefore}\nexport function gamma(): boolean { return true; }\n`;
const structuralAppend = exactChangedSpan(structuralBefore, structuralAfter);
assert.notEqual(
	structuralAppend.oldText,
	"}\n",
	"structural-3 core append span must not use ambiguous closing brace anchor",
);
assert.equal(
	structuralBefore.split(structuralAppend.oldText).length - 1,
	1,
	"structural-3 core append span oldText must be unique",
);
assert.equal(
	structuralBefore.replace(structuralAppend.oldText, structuralAppend.newText),
	structuralAfter,
	"structural-3 core append span must produce expected output",
);

const safetyFixtures = allEditTypesSafetyFixtures();
assert.deepEqual(
	safetyFixtures.map((fixture) => [
		fixture.classId,
		fixture.expectedOutcome,
		fixture.expectedMutation,
	]),
	[
		["E13", "noop", "none"],
		["E14", "decline", "none"],
		["E15", "decline", "none"],
		["E16", "decline", "none"],
		["E17", "decline", "none"],
		["E18", "decline", "none"],
	],
	"Sprint D safety rows must be classified as noop/decline/error with no mutation",
);
for (const fixture of safetyFixtures) {
	assert.ok(
		fixture.initial.length > 0,
		`${fixture.id} must define initial content`,
	);
	assert.ok(
		fixture.expectedClassification.length > 0,
		`${fixture.id} must define classification`,
	);
}
