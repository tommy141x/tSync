# Hero art

`scripts/thumb.ts` reads `tsync.jpg` from this directory and composites the
store/docs `thumb.jpg` and `banner.jpg` from it. It **refuses to build** without
it and names the missing file — a plausible-looking wrong hero is worse than no
hero.

## What the shot has to be

**Two patrol cars, light bars lit and in step.** That is the whole constraint,
and it is not an aesthetic preference: sync is a relationship *between*
vehicles, so a hero with one car in it is a hero for a different resource.

- Both light bars facing camera, cars side by side or slightly staggered
- Dusk or night, so the bars read against the sky rather than tarmac
- Clear weather, clean vehicles, no HUD, no player ped in frame
- Landscape, roughly 2560×1440 or larger. Anything Chromium can decode works —
  `.jpg`, `.png`, `.webp`

Capture it with tSync **running**, so the two bars are genuinely in step rather
than caught in a lucky frame. Spawn two class-18 vehicles, switch both sets of
lights on a second or two apart, wait five seconds for a pass, then shoot.

`SetVehicleHasMutedSirens(veh, true)` gives you the lights without the audio
while you are lining the shot up.

## After adding it

```bash
bun run thumb
```

Then look at `docs/public/thumb.jpg` and `banner.jpg` and nudge the `left` /
`top` / `width` offsets in `LAYERS` in `scripts/thumb.ts` — they are a starting
point for a 2560×1440 source and will not be right for an arbitrary capture.

The two store images in `assets/cfx/` (`01-hero.jpg`, `02-banner.jpg`) are the
generated pair, exported at upload order for the Cfx forum post.

## Why this is not already here

The in-game capture bridge on this machine returns sheared frames — the
framebuffer read is misaligned at every resolution tried, which is a fault in
the capture path rather than anything about the scene. A screenshot taken
normally is the way to produce this.
