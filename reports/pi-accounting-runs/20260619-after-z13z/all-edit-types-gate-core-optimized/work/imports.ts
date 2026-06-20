import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";

export async function load(path: string): Promise<string> {
  if (!existsSync(path)) return "";
  return readFile(path, "utf8");
}
