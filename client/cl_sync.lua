-- Brings nearby emergency lights back into step.
--
--  WHAT IS ACTUALLY WRONG, AND WHY THIS FIXES IT
--
-- GTA runs each vehicle's light pattern off a timer started when its siren was
-- switched on. Two cars that lit up a second apart flash a second apart for as
-- long as they are lit; nothing in the game ever pulls them together. Toggling
-- the siren flag restarts that timer, so toggling several vehicles in the same
-- frame starts their patterns together.
--
--  THIS IS A PER-OBSERVER FIX, AND THAT IS WHY THERE IS NO SERVER
--
-- The reset re-phases what THIS client draws, including vehicles it does not
-- own. Nothing is replicated and nothing needs to be: every client already
-- shares GetNetworkTimeAccurate(), so each one crosses the same interval
-- boundary at the same instant and reaches the same result independently.
-- Ultimate Lighting Controller does the same reset and then net-broadcasts it
-- to nearby clients (ulc/client/c_park.lua:94-115); with a shared clock that
-- round trip buys nothing, so tSync sends no net events at all.
--
--  WHAT IT CANNOT DO
--
-- Only vehicles lit by GTA's own system. That covers vanilla, Luxart, ULC and
-- the rest of the non-ELS world -- but a script that DRAWS its own lights is
-- untouched by the trick, because there is no engine timer behind them to
-- restart. Config.deferToTLS exists for that case, below.

if not tsyncConfigValid then return end

local SIREN_DOWN_FRAMES = 0

local math_floor = math.floor

--- Config.vehicleClasses as a set, built once. The pass below asks this per
--- vehicle per interval, and a linear scan of a list is the kind of cost that
--- only shows up on the server with the biggest fleet.
local wantedClass = {}
for _, class in ipairs(Config.vehicleClasses) do wantedClass[class] = true end

--- Server-synchronised milliseconds.
---
--- GetNetworkTimeAccurate() is the clock every client shares, which is the
--- whole reason this resource needs no coordination. It is not available until
--- the session has started, so the started state is latched and GetGameTimer()
--- covers the gap -- in singleplayer or during the first seconds of a join the
--- phase is merely local, which is correct for an observer who is alone anyway.
local netTimeStarted = false
local function getNetTime()
    if not netTimeStarted then netTimeStarted = HasNetworkTimeStarted() end
    if netTimeStarted then return GetNetworkTimeAccurate() end
    return GetGameTimer()
end

--- Which sibling resource, if any, is driving its own lights right now.
---
--- Resolved per pass rather than cached at boot: tLS can be started, stopped or
--- restarted while tSync runs, and a name latched at boot would be wrong for the
--- rest of the session in whichever direction it happened to be wrong.
---
--- Both spellings are probed because the resource was renamed from `tELS` to
--- `tLS` on 2026-10-24 and a server that has not updated still answers to the
--- old folder name. tLS first so that a server running both -- an old copy left
--- in place beside the new one -- is read from the one that is current.
local function lightingResource()
    if not Config.deferToTLS then return nil end
    if GetResourceState('tLS') == 'started' then return 'tLS' end
    if GetResourceState('tELS') == 'started' then return 'tELS' end
    return nil
end

--- Does another script own this vehicle's lights?
---
--- `AreLightsActive` answers nil for a vehicle it does not know about, which is
--- the three-state answer this needs: true and false both mean "configured
--- there, leave it alone". pcall because an export on a resource that stopped
--- between the check above and this call is a throw, not a nil, and that would
--- take the whole pass down rather than skipping one vehicle.
local function managedElsewhere(resource, vehicle)
    if not resource then return false end
    local ok, state = pcall(function()
        return exports[resource]:AreLightsActive(vehicle)
    end)
    return ok and state ~= nil
end

--- Vehicles this client should re-phase right now.
local function candidates()
    local here = GetEntityCoords(PlayerPedId())
    local radius = Config.radius
    local resource = lightingResource()
    local found = {}

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        -- Siren flag first: it is the cheapest of the three and rejects almost
        -- every vehicle in the pool on a normal server.
        if IsVehicleSirenOn(vehicle)
            and wantedClass[GetVehicleClass(vehicle)]
            and #(GetEntityCoords(vehicle) - here) <= radius
            and not managedElsewhere(resource, vehicle)
        then
            found[#found + 1] = vehicle
        end
    end

    return found
end

--- Last pass, for tsync_diag. Not used by anything else.
local lastPassCount, lastPassAt = 0, 0

--- Restart the light timer on every candidate together.
---
--- THE FRAME GAP IS LOAD-BEARING, AND IT IS MEASURED RATHER THAN REASONED.
--- Setting the flag false and true in the same frame leaves the engine nothing
--- to observe -- it reads the flag once per tick and would see only the final
--- value, so the reset would silently never happen. ULC writes both in one
--- frame; the script this one replaces waits a frame between them, and that is
--- the half worth keeping.
---
--- Measured on a live client 2026-10-25: polling IsVehicleSirenOn every frame
--- for 8 seconds across 1,012 frames caught the flag false on EXACTLY ONE
--- frame, at 2 ms past a 5000 ms boundary of the shared clock, with the siren
--- on before and after. One frame of darkness at an interval measured in
--- seconds is not visible; a sync that does nothing is not detectable at all,
--- which is the worse failure and the one this shape rules out.
---
--- Re-checked after the wait because a vehicle can be deleted inside it, and
--- SetVehicleSiren on a stale handle is a throw.
local function syncPass()
    local vehicles = candidates()
    if #vehicles == 0 then
        lastPassCount, lastPassAt = 0, getNetTime()
        return
    end

    for _, vehicle in ipairs(vehicles) do
        SetVehicleSiren(vehicle, false)
    end

    Wait(SIREN_DOWN_FRAMES)

    local restored = 0
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            SetVehicleSiren(vehicle, true)
            restored = restored + 1
        end
    end

    lastPassCount, lastPassAt = restored, getNetTime()
end

--- Sleeps to the next boundary rather than polling for it.
---
--- The boundary is a property of the shared clock -- `netNow - netNow %
--- interval` is the same instant on every client -- so the loop can compute how
--- long it has and wait exactly that long. Polling would wake this thread
--- hundreds of times per interval to answer a question arithmetic already
--- answers, and would still be late by up to one poll.
---
--- Waits are approximate, so the result is re-checked rather than trusted: if
--- the wake came early the remainder is waited again, and if it came late the
--- pass simply runs now.
CreateThread(function()
    local lastBoundary = -1

    while true do
        local interval = Config.intervalMs
        local now = getNetTime()
        local boundary = math_floor(now / interval)

        if boundary ~= lastBoundary then
            lastBoundary = boundary
            syncPass()
        end

        local untilNext = interval - (getNetTime() % interval)
        Wait(untilNext > 0 and untilNext or interval)
    end
end)

tlib.diag.command({
    name = 'tsync_diag',
    title = 'tSync diagnostics',
    spec = tsyncConfigSpec,
    report = function(ctx)
        local classes = {}
        for _, class in ipairs(Config.vehicleClasses) do classes[#classes + 1] = tostring(class) end

        ctx.line('tSync %s — tLib %s', ctx.meta(GetCurrentResourceName()), ctx.meta('tLib'))
        ctx.line('every %d ms, within %.0f m, classes %s',
            Config.intervalMs, Config.radius, table.concat(classes, ', '))

        -- The resolved answer, not the config flag. `deferToTLS = true` with no
        -- tLS running and `deferToTLS = false` behave identically, and an owner
        -- reading back the flag they set learns nothing about which it is.
        local resource = lightingResource()
        ctx.line('deferring to: %s', resource or (Config.deferToTLS and 'nothing running' or 'disabled'))

        if lastPassAt == 0 then
            ctx.line('no pass has run yet')
        else
            ctx.line('last pass re-phased %d vehicle(s), %.1f s ago',
                lastPassCount, (getNetTime() - lastPassAt) / 1000)
        end

        ctx.messages(tlib.config.validate(Config, tsyncConfigSpec))
    end,
})
