-- Re-phases nearby emergency lights by toggling the siren flag, which restarts
-- GTA's per-vehicle light pattern timer.
--
-- The reset is PER-OBSERVER, which is why there is no server and no net events:
-- it re-phases what THIS client draws, including vehicles it does not own, and
-- GetNetworkTimeAccurate() is already shared, so every client crosses the same
-- interval boundary independently. ULC does the same reset and then broadcasts it
-- (ulc/client/c_park.lua:94-115); with a shared clock that round trip buys nothing.
--
-- A script that DRAWS its own LEDs has no engine timer to restart, so it is
-- skipped unconditionally; see lightingResource.

if not tsyncConfigValid then return end

local SIREN_DOWN_FRAMES = 0

local math_floor = math.floor

local wantedClass = {}
for _, class in ipairs(Config.vehicleClasses) do wantedClass[class] = true end

--- The spawn-code lists, hashed once at load. GetHashKey lowercases, which is
--- what makes "Police3" and "police3" the same key with no case handling here.
local blacklisted, whitelisted = {}, {}
local hasWhitelist = false
for _, name in ipairs(Config.vehicleBlacklist) do blacklisted[GetHashKey(name)] = true end
for _, name in ipairs(Config.vehicleWhitelist) do
    whitelisted[GetHashKey(name)] = true
    hasWhitelist = true
end

--- The blacklist always wins, and a non-empty whitelist REPLACES the class check
--- rather than narrowing it.
local function modelWanted(vehicle)
    local model = GetEntityModel(vehicle)
    if blacklisted[model] then return false end
    if hasWhitelist then return whitelisted[model] == true end
    return wantedClass[GetVehicleClass(vehicle)] == true
end

--- Net time is not available until the session starts; GetGameTimer() covers the gap.
local netTimeStarted = false
local function getNetTime()
    if not netTimeStarted then netTimeStarted = HasNetworkTimeStarted() end
    if netTimeStarted then return GetNetworkTimeAccurate() end
    return GetGameTimer()
end

--- tLS was renamed from `tELS` on 2026-10-24, and a server that has not renamed
--- its folder still answers to the old name; tLS first, so a server running both
--- is read from the current one. Not cached: tLS can start or stop while tSync runs.
local function lightingResource()
    if GetResourceState('tLS') == 'started' then return 'tLS' end
    if GetResourceState('tELS') == 'started' then return 'tELS' end
    return nil
end

--- `AreLightsActive` answers nil only for a vehicle it has never heard of; true
--- and false both mean "configured there, leave it alone". pcall because an export
--- on a resource that stopped since the check above throws rather than answering nil.
local function managedElsewhere(resource, vehicle)
    if not resource then return false end
    local ok, state = pcall(function()
        return exports[resource]:AreLightsActive(vehicle)
    end)
    return ok and state ~= nil
end

local function candidates()
    local here = GetEntityCoords(PlayerPedId())
    local radius = Config.radius
    local resource = lightingResource()
    local found = {}

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        -- Siren flag first: it rejects almost the whole pool before the costlier checks.
        if IsVehicleSirenOn(vehicle)
            and modelWanted(vehicle)
            and #(GetEntityCoords(vehicle) - here) <= radius
            and not managedElsewhere(resource, vehicle)
        then
            found[#found + 1] = vehicle
        end
    end

    return found
end

local lastPassCount, lastPassAt = 0, 0

--- Drop every siren, wait a frame, raise every siren. Don't fuse these loops.
--- Fusing them restarts each timer at a different instant, which IS the drift.
--- Writing both values in one frame leaves the engine nothing to observe -- it
--- reads the flag once per tick and sees only the final value, so the reset
--- silently never happens. ULC writes both in one frame; the script this replaces
--- waits, and that is the half worth keeping.
---
--- The one frame of darkness is measured: on a live client 2026-10-25, polling
--- IsVehicleSirenOn across 1,012 frames caught the flag false on exactly one,
--- 2 ms past a 5000 ms boundary of the shared clock.
---
--- A vehicle can be deleted inside the wait, and SetVehicleSiren on a stale
--- handle throws.
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

--- Sleeps to the next boundary of the shared clock. Waits are approximate, so the
--- boundary is re-derived on each wake rather than trusted.
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

        local resource = lightingResource()
        ctx.line('deferring to: %s', resource or 'nothing running')
        ctx.line('spawn codes: %d blacklisted, %d whitelisted%s',
            #Config.vehicleBlacklist, #Config.vehicleWhitelist,
            #Config.vehicleWhitelist > 0 and ' (whitelist replaces the class check)' or '')

        if lastPassAt == 0 then
            ctx.line('no pass has run yet')
        else
            ctx.line('last pass re-phased %d vehicle(s), %.1f s ago',
                lastPassCount, (getNetTime() - lastPassAt) / 1000)
        end

        ctx.messages(tlib.config.validate(Config, tsyncConfigSpec))
    end,
})
