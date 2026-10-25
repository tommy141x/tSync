-- The startup update check: one request, an eight-second timeout, and nothing
-- held up if it fails.
--
-- `studios('tSync', current)` is the TIMMYG Studios product changelog API. It
-- reports "update check not run" rather than claiming the installed version is
-- current when the product is not published there yet, which is the failure this
-- provider is specified against.
local current = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)

tlib.versioncheck({
    name    = 'tSync',
    current = current,
    author  = 'TIMMYG Studios',
    fetch   = tlib.versioncheck.studios('tSync', current),
    -- One row, fired from onResourceStart below. NOT `required`: a config.lua
    -- with errors stops shared/config-spec.lua from setting a valid verdict,
    -- and a banner that refuses to draw because a row is absent is worse than a
    -- missing row -- on exactly the install that most needs the version check
    -- to still be readable.
    info    = {
        { key = 'Syncing', event = 'tsync:vcInfo:syncing' },
    },
})

-- The one fact a healthy boot is worth reporting, and it goes to the STARTUP
-- BANNER rather than a log line of its own: the banner already is the one-line
-- summary of a healthy boot, and a second line next to it is what makes
-- consoles scroll past it.
--
-- Fired from onResourceStart because this file subscribes the event inside
-- tlib.versioncheck above, and a TriggerEvent at file scope would race it.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    -- Reported from the server, which never runs a pass -- the work is entirely
    -- client-side. So this is the CONFIGURATION, not a count of anything done:
    -- "what this server has asked for", which is the fact an owner reading a
    -- boot banner can act on. A per-client count belongs to `tsync_diag`.
    local classes = {}
    for _, class in ipairs(Config.vehicleClasses or {}) do
        classes[#classes + 1] = tostring(class)
    end

    TriggerEvent('tsync:vcInfo:syncing', ('class %s every %dms within %.0fm')
        :format(table.concat(classes, '/'), Config.intervalMs, Config.radius))
end)
