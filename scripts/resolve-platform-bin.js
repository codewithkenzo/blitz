import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = dirname(here);

const platformPackage = () => {
  const { platform, arch } = process;
  if (platform === "linux" && arch === "x64") return "@codewithkenzo/blitz-linux-x64-musl";
  if (platform === "linux" && arch === "arm64") return "@codewithkenzo/blitz-linux-arm64-musl";
  if (platform === "darwin" && arch === "arm64") return "@codewithkenzo/blitz-darwin-arm64";
  if (platform === "darwin" && arch === "x64") return "@codewithkenzo/blitz-darwin-x64";
  if (platform === "win32" && arch === "x64") return "@codewithkenzo/blitz-windows-x64";
  return null;
};

export const candidateBinaries = () => {
  const exe = process.platform === "win32" ? "blitz.exe" : "blitz";
  const pkg = platformPackage();
  const candidates = [];
  if (process.env.BLITZ_BIN) candidates.push(process.env.BLITZ_BIN);
  if (pkg) {
    const unscoped = pkg.replace("@codewithkenzo/", "");
    candidates.push(join(root, "node_modules", pkg, "bin", exe));
    candidates.push(join(root, "..", unscoped, "bin", exe));
    candidates.push(join(root, "..", "..", pkg, "bin", exe));
  }
  candidates.push(join(root, "zig-out", "bin", exe));
  candidates.push(join(root, "bin", exe));
  return candidates;
};

export const findBlitzBinary = () => candidateBinaries().find((candidate) => existsSync(candidate));
