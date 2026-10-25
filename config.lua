--[[----------------------------------------------------------------------
    TIMMYG Studios — tSync 1.0.0
    config.lua — the file you edit. It is the only one.

    NOTHING HERE IS REQUIRED. tSync runs with zero edits.

    HOW TO EDIT: change values to the RIGHT of the = sign only. Keep the
    commas, and do not remove the quotes around text.

    APPLYING CHANGES: restart the resource. `ensure tSync` in the server
    console, or txAdmin > Resources > tSync > Restart. Nothing here is read
    again while the server runs.

    IF SOMETHING IS WRONG: `shared/config-spec.lua` checks this file at boot.
    Delete a key and it comes back as the value shipped here; set one to
    something illegal and you get a line naming the key, the file and the
    fix. Your file is never rewritten.

    Docs: https://timmygstudios.com/docs/tSync/configuration
------------------------------------------------------------------------]]

Config = {}

-- =========================================================================
--  1. TIMING — how often lights are brought back into step
-- =========================================================================
--  GTA runs each vehicle's light pattern on its own clock, started when the
--  siren was switched on. Two cars that lit up a second apart stay a second
--  apart forever. tSync restarts those clocks together so they flash as one.
--
--  THE NUMBER IS A CEILING ON DRIFT, NOT A REFRESH RATE. Nothing is redrawn
--  between passes; this is only how long two vehicles may stay visibly out
--  of step before they are pulled back together.
--
--  Lower is tighter and costs more: each pass walks the vehicles near you.
--  Below about 1000 the reset itself becomes visible as a stutter in the
--  pattern, which is worse than the drift it is fixing.

Config.intervalMs = 5000

-- =========================================================================
--  2. RANGE — how far out to bother
-- =========================================================================
--  Metres. Vehicles beyond this are left alone.
--
--  This is a RENDERING fix, so the only vehicles that matter are the ones on
--  screen. The default is a little past where lights stop being legible,
--  which costs a few extra vehicles per pass and means a car does not snap
--  into step as you drive up to it.

Config.radius = 150.0

-- =========================================================================
--  3. WHICH VEHICLES
-- =========================================================================
--  GTA vehicle class numbers. 18 is Emergency, which is every police car,
--  ambulance and fire truck in the base game and what almost every emergency
--  vehicle mod sets itself to.
--
--  Add 19 if your fleet includes Military-class vehicles with light bars.
--  The full list is at
--  https://docs.fivem.net/natives/?_0x29439776AAA00A62
--
--  A vehicle still has to have its lights ON to be touched: tSync never
--  switches anything on, it only re-times what is already running.

Config.vehicleClasses = { 18 }

-- =========================================================================
--  4. SCRIPTS THAT DRIVE THEIR OWN LIGHTS
-- =========================================================================
--  tSync works by restarting GTA's own light timer, so it only has any
--  effect on vehicles lit by GTA's own system -- vanilla, Luxart Vehicle
--  Control, Ultimate Lighting Controller, and the rest of the non-ELS world.
--
--  A script that DRAWS its own lights is untouched by the trick, but it may
--  still be using the siren flag for its AUDIO, and restarting that flag can
--  clip the siren. Leave this on to skip those vehicles entirely.
--
--  Today this means tLS (Tommy's Lighting System). The check costs one
--  export call per candidate vehicle per pass and is skipped outright when
--  tLS is not running, so there is nothing to turn off for performance.

Config.deferToTLS = true
