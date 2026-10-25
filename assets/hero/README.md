# Hero art

`scripts/thumb.ts` reads `tsync.jpg` from this directory and composites the
store/docs `thumb.jpg` and `banner.jpg` from it. It **refuses to build** without
it and names the missing file — a plausible-looking wrong hero is worse than no
hero.

## What the shot has to be

**Two patrol cars, light bars lit and in step.** That is the whole constraint,
and it is not an aesthetic preference: sync is a relationship _between_
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

## The current hero

`tsync.webp`, 1930×1042 lossless — three liveried units on the shoulder with
their bars lit in step. The cars sit at roughly x 700–1900 and y 320–780 of the
source; the empty road on the left is what the banner's copy lands on, which is
why that frames without a gap.

The offsets in `LAYERS` are tuned for those numbers. A replacement shot with a
different composition will need them re-tuned — render and look.

Captured normally rather than through the in-game bridge: that path returns
sheared frames on this machine at every resolution tried, with the scene fully
stationary. A fault in the capture hook, not the scene.
