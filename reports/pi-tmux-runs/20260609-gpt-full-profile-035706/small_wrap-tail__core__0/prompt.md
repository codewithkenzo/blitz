Apply this change to the file at reports/pi-tmux-runs/20260609-gpt-full-profile-035706/small_wrap-tail__core__0/work/small.ts. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.

Goal: change the body of the smallTarget function so it returns "hello " followed by name.toUpperCase() instead of "hi " + name. The signature stays the same.

Original file contents:
const helper = makeHelper();

function smallTarget(name: string): string {
  return "hi " + name;
}

const after = otherCall();
