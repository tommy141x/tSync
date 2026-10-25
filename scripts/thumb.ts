/**
 * `bun run thumb` — the store/docs hero and banner.
 *
 * The frame, the light rig and the guards are tLib's (`shared/ts/build/hero.ts`); this file is
 * only tSync's words and its layer placement.
 *
 * NO ART YET. tSync has no gallery: it is a reminder that fires on leaving a running vehicle,
 * so what it looks like is a prompt in the world, not a panel a headless browser can
 * photograph. Drop captures into `assets/hero/` and name them in LAYERS below. Until then this
 * exits 2 with the list of what it wanted, and writes no placeholder image — a
 * plausible-looking wrong hero is worse than no hero.
 *
 * Anything Chromium can decode works: `.png`, `.webp`, `.jpg`. A capture with a transparent
 * ground beats one with the game behind it — see tUnit's thumb for how those are placed, with
 * no border-radius and no box-shadow.
 *
 *   bun run thumb
 *   bun run thumb -- --format banner
 *   bun run thumb -- --subtitle "..."
 */

import fs from "node:fs";
import path from "node:path";
import { cliArg } from "../../tLib/shared/ts/build/argv.ts";
import { type HeroLayer, renderHero } from "../../tLib/shared/ts/build/hero.ts";

const REPO = path.resolve(import.meta.dir, "..");
const HERO = path.join(REPO, "assets", "hero");
const out = (name: string) => path.join(REPO, "docs", "public", name);

const headline = cliArg("headline") ?? "tSync";
const subtitle = cliArg("subtitle") ?? "Park-kill siren chirp reminder for FiveM";
const only = cliArg("format");

/**
 * One layer, and it is the whole frame rather than a panel floating in it.
 *
 * Every other resource composites UI captures onto this dark ground. tSync has no UI to
 * capture — it is a reminder that fires when you walk away from a running car — so the art is
 * a photograph of exactly that: a marked unit parked with its lights still going. A
 * photograph cannot be a floating rectangle with a shadow; it has to BE the background, with
 * the type sitting on a scrim over it.
 *
 * Two things make that work:
 *
 *   `-webkit-mask-image`   fades the photo out where the type goes, so the headline sits on
 *                          the frame's own black instead of on a bright daylight sky. The
 *                          prefix is load-bearing: this renders in the vendored NUI Chromium,
 *                          revision 103, and unprefixed `mask-image` only arrived in 120 —
 *                          unprefixed it is ignored and the photo runs behind the wordmark at
 *                          full strength.
 *   `filter: brightness`   the source is bright midday GTA and this frame is near-black. At
 *                          full strength the photo reads as a different image pasted in.
 *
 * Mask percentages are relative to the IMAGE, which is larger than the frame and offset, so
 * they do not line up with frame percentages. The car sits at roughly 39% across and 26-60%
 * down the source, which is what the offsets below are positioning.
 */
const LAYERS: { file: string; thumb: string; banner: string }[] = [
  {
    // Two patrol cars, light bars lit and IN STEP -- the whole product in one
    // frame. A single car cannot show this feature: sync is a relationship
    // between vehicles, so a hero with one car in it is a hero for a different
    // resource.
    //
    // Shoot it at dusk or night with the bars facing camera. The offsets below
    // are a starting point for a roughly 2560x1440 capture and will need
    // nudging to whatever lands here -- run `bun run thumb` and look.
    file: "tsync.jpg",
    thumb: `width: 3200px; left: -420px; top: 40px; border-radius: 0;
            filter: brightness(.52) saturate(.95) contrast(1.06);
            -webkit-mask-image: linear-gradient(to bottom, transparent 8%, rgba(0,0,0,.35) 26%, #000 44%);
            mask-image: linear-gradient(to bottom, transparent 8%, rgba(0,0,0,.35) 26%, #000 44%);`,
    banner: `width: 1750px; left: 230px; top: -110px; border-radius: 0;
             filter: brightness(.56) saturate(.95) contrast(1.06);
             -webkit-mask-image: linear-gradient(to right, transparent 2%, rgba(0,0,0,.3) 20%, #000 40%);
             mask-image: linear-gradient(to right, transparent 2%, rgba(0,0,0,.3) 20%, #000 40%);`,
  },
];

const missing = LAYERS.map((l) => l.file).filter((f) => !fs.existsSync(path.join(HERO, f)));
if (missing.length) {
  console.error(`tSync has no hero art yet. Put these in ${path.relative(REPO, HERO)}/:`);
  for (const f of missing) console.error(`  ${f}`);
  console.error("Then adjust LAYERS in scripts/thumb.ts to size and angle them.");
  process.exit(2);
}

const layers = (format: "thumb" | "banner"): HeroLayer[] =>
  LAYERS.map((l) => ({ file: path.join(HERO, l.file), css: l[format] }));

/** Six characters against tRadio's thirteen, so this runs above the 148px default to land on a
 *  comparable lockup width — matching the font-size would make the shorter name look small. */
if (only !== "banner") {
  await renderHero({
    format: "thumb",
    headline,
    subtitle,
    headlineSize: 172,
    // Full frame, not the default band below the type: this layer IS the background.
    stageCss: "top: 0; height: 1080px;",
    layers: layers("thumb"),
    out: out("thumb.jpg"),
  });
}
if (only !== "thumb") {
  await renderHero({
    format: "banner",
    headline,
    subtitle,
    headlineSize: 104,
    layers: layers("banner"),
    out: out("banner.jpg"),
  });
}
