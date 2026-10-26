--[[----------------------------------------------------------------------
    TIMMYG Studios — tSync 1.0.0
    config.lua — the only file you edit, and nothing in it is required.

    Change values to the RIGHT of the = only. Restart the resource to apply;
    nothing here is read again while the server runs.

    `shared/config-spec.lua` checks this file at boot. Delete a key and it
    comes back as the value shipped here; set one to something illegal and
    you get a line naming the key, the file and the fix. Your file is never
    rewritten.

    Docs: https://timmygstudios.com/docs/tSync/configuration
------------------------------------------------------------------------]]

Config = {}

-- TIMING — how often lights are pulled back into step.
--
-- A CEILING ON DRIFT, NOT A REFRESH RATE: nothing is redrawn between passes,
-- this is only how long two vehicles may stay visibly apart. Lower is tighter
-- and costs more, and below about 1000 the reset itself reads as a stutter.

Config.intervalMs = 5000

-- RANGE, in metres. Vehicles beyond this are left alone.
--
-- A rendering fix, so only what is on screen matters. The default is a little
-- past where light bars stop being legible, so a car does not snap into step
-- as you drive up to it.

Config.radius = 150.0

-- WHICH VEHICLES — GTA class numbers. 18 is Emergency: every police car,
-- ambulance and fire truck in the base game, and what almost every emergency
-- mod sets itself to. Add 19 for Military-class vehicles with light bars.
-- Full list: https://docs.fivem.net/natives/?_0x29439776AAA00A62
--
-- Lights still have to be ON. tSync never switches anything on.

Config.vehicleClasses = { 18 }

-- BLACKLIST — never sync these, whatever their class. Spawn codes, the same
-- strings you would use with /car; case does not matter.
--
--     Config.vehicleBlacklist = { "firetruk", "ambulance" }
--
-- For a model whose lights look wrong re-timed, or one running a lighting
-- script tSync cannot detect.

Config.vehicleBlacklist = {}

-- WHITELIST — sync ONLY these.
--
--     Config.vehicleWhitelist = { "police3", "sheriff2" }
--
-- ⚠️ A NON-EMPTY WHITELIST REPLACES THE CLASS CHECK ABOVE rather than
-- narrowing it. The case it exists for is a vehicle pack that did not ship as
-- class 18: name it here and it syncs, which an extra filter on top of the
-- classes could not express.
--
-- The blacklist still wins, and a model in both lists is reported at boot
-- rather than silently resolved.

Config.vehicleWhitelist = {}
