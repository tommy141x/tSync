/**
 * Parses every Lua file in the resource without executing it: `bun run check:syntax`
 *
 * `bun test` never loads a line of Lua, and the fengari suites only load the
 * files they are oracles for, so without this a missing `end` anywhere else first
 * surfaces as a resource that refuses to start on a live server.
 *
 * Suites included: one that does not parse is reported by the test runner as a
 * failure with no message, so parsing it here turns that into a file and a line.
 * Discovered off disk, because a hardcoded list keeps passing while the file
 * nobody added to it is the broken one.
 *
 * EXIT CODES, measured directly:
 *
 *   0  every file parses
 *   1  a file failed to parse
 *   2  could not measure — zero files found. ⚠️ NOT a pass: a glob that stops
 *      matching after a move reports no syntax errors, and "no errors" and
 *      "nothing was read" are otherwise the same green.
 *
 * ⚠️ Read the exit code from `Bun.spawnSync().exitCode`, never from `$?` after a
 * pipe: `… | head` hands you `head`'s status.
 *
 * `SYNTAX_CONTROL=1` is this gate's negative control — see the block below.
 * `--root=DIR` points the scan elsewhere and exists only for that control.
 */
import { resolve } from "node:path";

const SELF = "check:syntax";

/**
 * Excluded because it holds a file that cannot parse by design — including it
 * would make this gate permanently red, and deleting the fixture removes the
 * proof that the gate works.
 *
 * scripts/controls/lua/ is NOT excluded: those two fixtures are valid Lua and
 * must parse, or the Lua gate's control measures a syntax error rather than the
 * hazard it names.
 */
const CONTROL_FIXTURES = "scripts/controls/syntax/";

async function scan(root: string): Promise<string[]> {
  // Bun.Glob hands back backslashes on Windows, so a filter written against
  // "node_modules/" silently matches nothing there — the difference between
  // skipping a dependency tree and parsing it.
  return (await Array.fromAsync(new Bun.Glob("**/*.lua").scan({ cwd: root })))
    .map((p) => p.replaceAll("\\", "/"))
    .filter((p) => !p.startsWith("node_modules/"))
    .filter((p) => !p.startsWith(CONTROL_FIXTURES))
    .sort();
}

/** Parse every Lua file under `root`. Returns this gate's exit code. */
async function check(root: string, quiet = false): Promise<number> {
  const files = await scan(root);

  if (files.length === 0) {
    console.error(
      `${SELF}: found no Lua files under ${root}. Exit 2, not 0 — a run that read ` +
        "nothing has proven nothing."
    );
    return 2;
  }

  const result = Bun.spawnSync(
    [
      "bunx",
      "--bun",
      "--package",
      "fengari-node-cli",
      "fengari",
      // Absolute: the Lua shim is always this resource's, whatever `root` is.
      resolve(import.meta.dir, "syntax-check.lua"),
      ...files,
    ],
    {
      cwd: root,
      stdout: quiet ? "pipe" : "inherit",
      stderr: quiet ? "pipe" : "inherit",
    }
  );
  // `exitCode` is null when the process was killed by a signal, which is a
  // failure and must not read as 0.
  return result.exitCode ?? 1;
}

const ROOT = resolve(import.meta.dir, "..");
const rootArg = process.argv.find((a) => a.startsWith("--root="));

// ── Negative control (SYNTAX_CONTROL=1) ─────────────────────────────────────
//
// Both of this gate's failure modes are invisible from a green run: the glob
// could stop matching, or the Lua shim's `loadfile` could stop being consulted,
// and either way every run after reports "all files parse".
//
// THE DECOY CASE IS NOT OPTIONAL. A harness that has stopped reading exit codes
// reports every case as failing, which is what a correct run of the two red cases
// looks like too. So the real resource root must still come back GREEN.
if (process.env.SYNTAX_CONTROL === "1") {
  const fixtures = resolve(ROOT, CONTROL_FIXTURES);
  const failures: string[] = [];

  const expect = async (label: string, root: string, want: number) => {
    const got = await check(root, true);
    if (got === want) {
      console.log(`  as required  exit ${got}  ${label}`);
    } else {
      failures.push(`${label}: wanted exit ${want}, got ${got}`);
      console.log(`  WRONG        exit ${got} (wanted ${want})  ${label}`);
    }
  };

  // The whole claim of the gate.
  await expect("a Lua file with a missing `end`", fixtures, 1);

  // What a renamed or moved source tree looks like: 2, never 0.
  await expect("a directory with no Lua in it", resolve(fixtures, "empty"), 2);

  // The decoy, or the two cases above prove nothing.
  await expect("tSync's real source tree, which must stay GREEN", ROOT, 0);

  console.log("");
  if (failures.length > 0) {
    for (const f of failures) console.error(`FAIL  ${f}`);
    process.exit(1);
  }
  console.log(`PASS  ${SELF} is demonstrably capable of failing, and of passing.`);
  process.exit(0);
}

process.exit(await check(rootArg ? resolve(rootArg.slice("--root=".length)) : ROOT));
