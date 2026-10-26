-- `studios()` is the TIMMYG Studios changelog API. A product not published there
-- yet reports "update check not run" rather than claiming the installed version
-- is current.
local current = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)

tlib.versioncheck({
    name    = 'tSync',
    current = current,
    author  = 'TIMMYG Studios',
    fetch   = tlib.versioncheck.studios('tSync', current),
    -- Not `required`: a config.lua with errors leaves this row unfilled, and the
    -- banner must still draw on exactly that install.
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
