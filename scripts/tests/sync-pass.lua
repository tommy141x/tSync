-- client/cl_sync.lua — which vehicles get re-phased, and in what order.
--
-- THE ORDERING IS THE WHOLE FEATURE: every candidate's siren must be dropped
-- before any is raised again. The code is two plain loops and nothing about its
-- shape says they may not be fused, so that property is pinned here.
--
-- The selection rules are pinned for a duller reason: every one of them fails
-- silently. A wrong class, a radius comparison the wrong way round or a
-- backwards deference check produces a resource that does nothing or fights
-- another script, and neither writes a line anywhere.

local ROOT = (arg[0] or ''):match('^(.*)scripts[/\\]tests[/\\]') or './'
local function path(p) return ROOT .. p end

local checks = 0
local function check(value, message)
    checks = checks + 1
    assert(value, message)
end

-- ── Host stubs ─────────────────────────────────────────────────────────────

-- fengari has no vector3, and the distance rule is one of the things pinned
-- here, so this answers `#(a - b)` rather than collapsing to a number.
local function vec(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, {
        __sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
    })
end

local world = {}        -- handle -> { class, siren, coords, managed, exists }
local playerAt = vec(0, 0, 0)

function PlayerPedId() return 1 end
function GetGamePool(name)
    check(name == 'CVehicle', 'the pool asked for is CVehicle')
    local out = {}
    for handle in pairs(world) do out[#out + 1] = handle end
    table.sort(out)
    return out
end
function GetEntityCoords(entity)
    if entity == 1 then return playerAt end
    return (world[entity] or {}).coords or vec(0, 0, 0)
end
function IsVehicleSirenOn(v) return (world[v] or {}).siren == true end
function GetVehicleClass(v) return (world[v] or {}).class or 0 end
function DoesEntityExist(v) return (world[v] or {}).exists ~= false end

-- LOWERCASES, because the real joaat does, and that is the only property of the
-- hash the selection code relies on. A stub preserving case would let a case
-- regression pass here and fail in game.
function GetHashKey(s) return 'hash:' .. tostring(s):lower() end
function GetEntityModel(v) return GetHashKey((world[v] or {}).model or 'unknown') end

-- In order, which is what the ordering check reads.
local calls = {}
function SetVehicleSiren(v, on) calls[#calls + 1] = { vehicle = v, on = on } end

local netNow = 0
function HasNetworkTimeStarted() return true end
function GetNetworkTimeAccurate() return netNow end
function GetGameTimer() return netNow end
function GetCurrentResourceName() return 'tSync' end

local started = {}
function GetResourceState(name) return started[name] or 'missing' end

-- Must THROW for a resource that is not running, exactly as FiveM does: that is
-- the case the pcall in managedElsewhere exists for, and a stub answering nil
-- would let a real regression pass.
exports = setmetatable({}, {
    __index = function(_, resource)
        if started[resource] ~= 'started' then
            error(('No such export AreLightsActive in resource %s'):format(resource), 2)
        end
        return {
            AreLightsActive = function(_, v)
                return (world[v] or {}).managed
            end,
        }
    end,
})

-- Captured rather than run, so the suite can drive one iteration at a time and
-- move the clock between passes.
local threadBody
function CreateThread(fn) threadBody = fn end

local waits = {}
function Wait(ms) waits[#waits + 1] = ms end

local diag
tlib = {
    diag = { command = function(opts) diag = opts end },
    config = { validate = function() return {} end },
}

Config = {
    intervalMs = 5000,
    radius = 150.0,
    vehicleClasses = { 18 },
    vehicleBlacklist = {},
    vehicleWhitelist = {},
}
tsyncConfigValid = true

dofile(path('client/cl_sync.lua'))
check(type(threadBody) == 'function', 'the sync loop registered a thread')
check(type(diag) == 'table' and diag.name == 'tsync_diag', 'tsync_diag registered')

-- ── Driving one pass ───────────────────────────────────────────────────────

--- Runs the loop until it has waited `n` times, then returns.
local function runUntilWait(n)
    local co = coroutine.create(threadBody)
    local seen = 0
    local realWait = Wait
    Wait = function(ms)
        waits[#waits + 1] = ms
        seen = seen + 1
        if seen >= n then coroutine.yield() end
    end
    coroutine.resume(co)
    Wait = realWait
end

local function reset()
    world, calls, waits = {}, {}, {}
    playerAt = vec(0, 0, 0)
    started = {}
end

local function addVehicle(handle, opts)
    world[handle] = {
        class = opts.class or 18,
        siren = opts.siren ~= false,
        coords = opts.coords or vec(0, 0, 0),
        managed = opts.managed,
        exists = opts.exists,
        model = opts.model or 'police',
    }
end

--- Re-load cl_sync.lua with a different Config.
---
--- The spawn-code lists are hashed ONCE at load, so mutating Config afterwards
--- tests nothing. The first version of these checks did exactly that and passed
--- the blacklist case for the wrong reason.
local function reloadWith(overrides)
    for key, value in pairs(overrides) do Config[key] = value end
    dofile(path('client/cl_sync.lua'))
end

local function sirenCalls(vehicle)
    local out = {}
    for _, call in ipairs(calls) do
        if call.vehicle == vehicle then out[#out + 1] = call.on end
    end
    return out
end

-- ── Selection ──────────────────────────────────────────────────────────────

do
    reset()
    addVehicle(10, {})                                    -- eligible
    addVehicle(11, { siren = false })                     -- lights off
    addVehicle(12, { class = 0 })                         -- wrong class
    addVehicle(13, { coords = vec(500, 0, 0) })           -- too far
    runUntilWait(2)

    check(#sirenCalls(10) == 2, 'an eligible vehicle is re-phased')
    check(#sirenCalls(11) == 0, 'a vehicle with its lights off is left alone')
    check(#sirenCalls(12) == 0, 'a vehicle outside vehicleClasses is left alone')
    check(#sirenCalls(13) == 0, 'a vehicle beyond the radius is left alone')
end

-- An inclusive/exclusive slip here is invisible in game.
do
    reset()
    addVehicle(10, { coords = vec(150, 0, 0) })
    addVehicle(11, { coords = vec(150.1, 0, 0) })
    runUntilWait(2)
    check(#sirenCalls(10) == 2, 'a vehicle exactly at the radius is included')
    check(#sirenCalls(11) == 0, 'a vehicle just past the radius is not')
end

-- ── Ordering: every drop before any raise ──────────────────────────────────

do
    reset()
    for handle = 10, 14 do addVehicle(handle, {}) end
    runUntilWait(2)

    check(#calls == 10, 'five vehicles produce ten calls')

    local raisedYet = false
    for _, call in ipairs(calls) do
        if call.on then
            raisedYet = true
        else
            check(not raisedYet,
                'every siren is dropped before any is raised -- fusing the two loops '
                    .. 'restarts each timer at a different instant, which is the drift itself')
        end
    end
    check(raisedYet, 'the sirens are raised again')
end

-- ── Deference ──────────────────────────────────────────────────────────────

do
    reset()
    started['tLS'] = 'started'
    addVehicle(10, { managed = true })    -- tLS, lights on
    addVehicle(11, { managed = false })   -- tLS, lights off: still tLS's
    addVehicle(12, { managed = nil })     -- not a tLS vehicle
    runUntilWait(2)

    check(#sirenCalls(10) == 0, 'a vehicle tLS is lighting is left alone')
    check(#sirenCalls(11) == 0,
        'false means "configured in tLS, currently off" and is still not ours -- '
            .. 'only nil means tLS has never heard of this vehicle')
    check(#sirenCalls(12) == 2, 'a vehicle tLS does not know about is re-phased')
end

do
    reset()
    started['tELS'] = 'started'
    addVehicle(10, { managed = true })
    runUntilWait(2)
    check(#sirenCalls(10) == 0,
        'the pre-2026-10-24 resource name still defers -- a server that has not '
            .. 'renamed its folder is the one most likely to be running both')
end

-- tLS not running at all: the export throws, and that must skip the check
-- rather than take the pass down with it.
do
    reset()
    addVehicle(10, { managed = true })   -- would be deferred if tLS were up
    runUntilWait(2)
    check(#sirenCalls(10) == 2, 'with tLS stopped the export is never consulted')
end

-- ── A vehicle deleted inside the frame gap ─────────────────────────────────

do
    reset()
    addVehicle(10, {})
    addVehicle(11, {})
    -- Deleted after selection, which is the window the re-check exists for.
    local realWait = Wait
    local co = coroutine.create(threadBody)
    local seen = 0
    Wait = function(ms)
        seen = seen + 1
        if seen == 1 then world[11].exists = false end
        if seen >= 2 then coroutine.yield() end
    end
    coroutine.resume(co)
    Wait = realWait

    check(#sirenCalls(11) == 1,
        'a vehicle deleted during the frame gap is dropped and never raised, '
            .. 'rather than throwing on a stale handle')
    check(#sirenCalls(10) == 2, 'its neighbour is unaffected')
end

-- ── Spawn-code lists ──────────────────────────────────────────────────────
--
-- A blacklisted model that still syncs, or a whitelisted one that does not,
-- produces no error anywhere. The whitelist's interaction with vehicleClasses is
-- the part most likely to be "simplified" later, so it is asserted both ways.

do
    reset()
    reloadWith({ vehicleBlacklist = { 'firetruk' } })
    addVehicle(10, { model = 'police' })
    addVehicle(11, { model = 'firetruk' })
    runUntilWait(2)
    check(#sirenCalls(10) == 2, 'a model not on the blacklist still syncs')
    check(#sirenCalls(11) == 0, 'a blacklisted model is never re-phased')
    reloadWith({ vehicleBlacklist = {} })
end

do
    reset()
    reloadWith({ vehicleBlacklist = { 'FireTruk' } })
    addVehicle(10, { model = 'firetruk' })
    runUntilWait(2)
    check(#sirenCalls(10) == 0,
        'spawn codes match case-insensitively -- the hash lowercases, so an '
            .. 'owner writing "FireTruk" is not silently ignored')
    reloadWith({ vehicleBlacklist = {} })
end

do
    reset()
    reloadWith({ vehicleWhitelist = { 'police3' } })
    addVehicle(10, { model = 'police3' })
    addVehicle(11, { model = 'police' })      -- class 18, but not listed
    runUntilWait(2)
    check(#sirenCalls(10) == 2, 'a whitelisted model syncs')
    check(#sirenCalls(11) == 0,
        'a non-whitelisted model does NOT sync even though its class matches -- '
            .. 'a non-empty whitelist replaces the class check')
    reloadWith({ vehicleWhitelist = {} })
end

-- The case the whitelist exists for: a pack that did not ship as class 18. An
-- "extra filter on top of the classes" reading could not express it.
do
    reset()
    reloadWith({ vehicleWhitelist = { 'customcruiser' } })
    addVehicle(10, { model = 'customcruiser', class = 0 })
    runUntilWait(2)
    check(#sirenCalls(10) == 2,
        'a whitelisted model syncs regardless of its class')
    reloadWith({ vehicleWhitelist = {} })
end

-- Which way the code resolves an overlap. config-spec.lua reports it at boot.
do
    reset()
    reloadWith({ vehicleBlacklist = { 'police3' }, vehicleWhitelist = { 'police3' } })
    addVehicle(10, { model = 'police3' })
    runUntilWait(2)
    check(#sirenCalls(10) == 0, 'in both lists means never synced')
    reloadWith({ vehicleBlacklist = {}, vehicleWhitelist = {} })
end

-- ── Deference is unconditional ────────────────────────────────────────────
--
-- Pinned because the obvious "add a flag back" change reintroduces a switch
-- whose only effect is letting tSync fight a script that owns the vehicle.
do
    reset()
    started['tLS'] = 'started'
    addVehicle(10, { managed = true })
    runUntilWait(2)
    check(#sirenCalls(10) == 0, 'a tLS vehicle is skipped with no config involved')
end

-- ── The shared clock decides when ──────────────────────────────────────────

do
    reset()
    addVehicle(10, {})
    netNow = 10000

    local co = coroutine.create(threadBody)
    local passes, seen = 0, 0
    Wait = function()
        seen = seen + 1
        -- Same interval: 10000 and 12000 are both boundary 2.
        if seen == 2 then netNow = 12000 end
        if seen == 4 then netNow = 15000 end
        if seen >= 6 then coroutine.yield() end
    end
    coroutine.resume(co)

    passes = #sirenCalls(10) / 2
    check(passes == 2,
        ('two boundaries crossed means two passes, got %d -- a loop that synced on '
            .. 'every wake would re-phase constantly'):format(passes))
end

print(('PASS: %d sync-pass checks'):format(checks))
