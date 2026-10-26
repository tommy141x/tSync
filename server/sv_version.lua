-- The startup update check: one request, an eight-second timeout, nothing held
-- up if it fails.
--
-- `studios()` is the TIMMYG Studios changelog API. When a product is not
-- published there yet it reports "update check not run" rather than claiming the
-- installed version is current, which is the failure it is specified against.
local current = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)

tlib.versioncheck({
    name    = 'tSync',
    current = current,
    author  = 'TIMMYG Studios',
    fetch   = tlib.versioncheck.studios('tSync', current),
    -- Not `required`: a config.lua with errors stops this row being filled, and
    -- a banner that refuses to draw is worse than a missing row on exactly the
    -- install that most needs the version check to still be readable.
    info    = {
        { key = 'Syncing', event = 'tsync:vcInfo:syncing' },
    },
})

-- Fired from onResourceStart because tlib.versioncheck above subscribes the
-- event, and a TriggerEvent at file scope would race it.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    local classes = {}
    for _, class in ipairs(Config.vehicleClasses or {}) do
        classes[#classes + 1] = tostring(class)
    end

    TriggerEvent('tsync:vcInfo:syncing', ('class %s every %dms within %.0fm')
        :format(table.concat(classes, '/'), Config.intervalMs, Config.radius))
end)
