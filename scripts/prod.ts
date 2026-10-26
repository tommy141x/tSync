/**
 * `bun run prod` — cut the release zip.
 *
 * Nothing here to obfuscate and no provenance token to arm, so what is left is
 * the part that actually goes wrong: deciding what ships.
 */
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import AdmZip from "adm-zip";
import {
  assertManifestStaged,
  checkStagedTree,
  createZip,
  failing,
  formatFindings,
  mergeLicenceFiles,
  stageFiles,
  step,
} from "../../tLib/shared/ts/build/index.ts";

const ROOT = resolve(join(import.meta.dir, ".."));
// Everything generated lands under one root, so .gitignore needs a single rule —
// and it already has it: `.build/`.
const DIST = join(ROOT, ".build", "dist");

// An allowlist. A denylist ships anything nobody thought to name; naming what
// ships means a new file is ABSENT until someone adds it here, and both
// directions are checked below, so an unlisted runtime file fails the build
// loudly instead of shipping broken.
//
// File by file rather than as `client`, `server`, `shared`: those directories
// hold exactly the manifest's scripts today, so a tree-level entry would be
// identical — right up to the first helper, fixture or note filed beside them,
// which would then ship silently. tAFK's comment records what that cost it.
//
// Deliberately absent: `scripts/` (a release already has what the gates
// produce), `docs/` (published to timmygstudios.com by .gitea/workflows/docs.yml,
// not to a server owner), `node_modules/`, `.build/`, and the repo's own tooling
// — package.json, bun.lock, biome.json, .githooks, .gitea.
const INCLUDE = [
  "fxmanifest.lua",
  // The full docs are on the site; a server owner who downloaded a zip has this.
  "README.md",
  "config.lua",
  "shared/config-spec.lua",
  "client/cl_sync.lua",
  "server/sv_version.lua",
];

// Both directions, because neither check can see the other's failure.
// `stageFiles` throws on an included path that has stopped existing — a rename
// or a move. `assertManifestStaged` throws on a path fxmanifest.lua declares
// that nobody added to INCLUDE — a release that builds clean and then fails at
// load on someone's server.
//
// ⚠️ Both nets were WATCHED failing, which is what makes the allowlist safe to
// maintain by hand. No permanent control for it here: the checks are tLib's,
// shared with eight resources, and tLib's `check:regression` owns their
// fixtures. Reproduce by redoing either edit:
//
//   · `client/cl_sync.lua` removed from INCLUDE → exit 1, "fxmanifest.lua names
//     1 path(s) the release does not stage". An unlisted runtime file cannot
//     ship silently.
//   · a `data.json` planted at the root and added to INCLUDE → exit 1,
//     R-DATA-FILE. Runtime state cannot reach the archive.
assertManifestStaged(readFileSync(join(ROOT, "fxmanifest.lua"), "utf8"), INCLUDE);

stageFiles(ROOT, DIST, INCLUDE);

step("Merging the licence and notices");
{
  const bundle = mergeLicenceFiles({
    root: ROOT,
    dist: DIST,
    name: "tSync",
    sources: [{ title: "Licence (MIT)", file: "LICENSE" }],
  });
  console.log(
    `  ${bundle.out} — ${bundle.sections.length} section(s), ${(bundle.bytes / 1024).toFixed(1)} KB`
  );
}

// MIT requires the notice in every copy, and the only thing putting it there is
// the `sources` entry above. `assertManifestStaged` cannot cover it: it compares
// against fxmanifest.lua, which declares neither LICENSE nor README because
// neither is a script. MEASURED: dropping that entry built green and produced a
// zip with no licence in it.
const licence = join(DIST, "server", "LICENSE.txt");
if (!existsSync(licence) || !readFileSync(licence, "utf8").includes("MIT License")) {
  console.error("No MIT text in server/LICENSE.txt — MIT needs the notice inside the zip.");
  process.exit(1);
}

// ── Runtime state must not be in the archive ────────────────────────────────
//
// tSync writes no data.json, calls no SaveResourceFile and opens no kvp or
// jsonstore. The allowlist above is what keeps that true, and an allowlist is
// edited by hand — the day tSync gains a store, the first release after it is
// where a copy of the developer's file would ship, and this is what stops it
// rather than a reviewer remembering.
//
// `minFiles` is 5 against a staged tree of 7: a floor against a collapsed or
// wrong-directory scan, not a budget, because every rule in the set is green on
// an empty directory.
step("Checking the staged tree for runtime state");
const staged = checkStagedTree({ dist: DIST, minFiles: 5 });
const findings = failing(staged.findings, false);
const summary = `${staged.fileCount} file(s), ${(staged.totalBytes / 1024).toFixed(0)} KB staged`;
if (findings.length > 0) {
  console.error(formatFindings("staged tree", findings, summary));
  process.exit(1);
}
console.log(formatFindings("staged tree", findings, `${summary}, no forbidden runtime state`));

// `expectConfig` stays at its default (true): tSync ships `config.lua`, so there
// IS a file for the sanitizer to read. Zero config files found would be the
// silent-zero the default refusal exists to catch.
step("Packaging");
// One merged `server/LICENSE.txt` rather than legal files at the resource root,
// which is what an operator sees on extracting the zip and is not where any of
// them belongs. The repo keeps them separate -- different things edit them at
// different times -- so the merge happens here, on the staged tree.
createZip(new AdmZip(), DIST, join(ROOT, ".build", "tSync.zip"), "tSync");
