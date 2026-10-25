-- Startup validation for config.lua, through tlib.config.
--
-- Runs on BOTH VMs, immediately after config.lua and before any client chunk,
-- so a mistyped key is a line in the console at boot instead of a setting that
-- silently did nothing forever. Unvalidated, `intervalMs` spelled `intervalMS`
-- reaches the sync loop as nil and divides by it, which throws inside a
-- CreateThread and kills the loop for the rest of the session while naming
-- neither the file nor the key.
--
-- Where the numbers live
--
-- `config.lua` IS THE AUTHORITY. The `default =` fields below are only what
-- tlib.config writes into `Config` for a key the owner DELETED; tlib.config
-- never overwrites a value the owner actually set. `scripts/tests/config-spec.lua`
-- asserts the two files agree, literal for literal, and that the shipped file
-- passes its own spec with zero errors and zero warnings.
--
-- `vehicleClasses` is declared as a type only. Its INSIDE is checked below, by
-- code, because the mistake that actually happens there is not a wrong type --
-- it is `18` written bare instead of `{ 18 }`, or a class number outside the
-- range GTA defines, and neither is expressible as a per-key rule.

local RESOURCE = 'tSync'
local FILE = 'config.lua'

--- Global so `tsync_diag` can re-run the same checks on demand rather than
--- asking an owner to restart and catch the boot lines scrolling past.
tsyncConfigSpec = {
    file = FILE,
    resource = RESOURCE,
    keys = {
        -- min 250 rather than 1: below roughly a second the reset is visible as
        -- a stutter, and at a handful of milliseconds it is a vehicle walk every
        -- frame. 250 is well past useful and still finite, which is what the
        -- bound is for -- an owner who writes 0 gets a named error instead of a
        -- frozen client.
        --
        -- No max. A very large value is not a mistake: it is "sync rarely",
        -- which is a legitimate choice on a server that mostly parks.
        intervalMs = { type = 'number', default = 5000, min = 250 },

        -- Metres. min 1.0 because 0 disables the feature in a way that reads
        -- like a setting rather than an off switch -- an owner who wants tSync
        -- off should stop the resource, not set its radius to nothing.
        --
        -- max 500 is the point past which the vehicles being walked are not
        -- rendered at all, so the work is certain waste. It is a guard against
        -- a typo'd extra zero, not a tuning opinion.
        radius = { type = 'number', default = 150.0, min = 1.0, max = 500.0 },

        -- Type only; the contents are checked in crossChecks below.
        vehicleClasses = { type = 'table' },

        -- Type only; the contents are checked in crossChecks below, where a
        -- spawn code that is not a string can be named.
        vehicleBlacklist = { type = 'table' },
        vehicleWhitelist = { type = 'table' },
    },
}

-- GTA defines classes 0-22. A number outside that matches no vehicle, so the
-- entry is not wrong in a way anything will ever report -- it simply never
-- fires, which is indistinguishable from "tSync does not work on my fleet".
local MAX_VEHICLE_CLASS = 22

--- Checks that cannot be expressed as per-key rules.
--- @param cfg table
--- @return table list of problem strings
local function crossChecks(cfg)
    local problems = {}
    local function bad(message)
        problems[#problems + 1] = ('[%s] %s'):format(RESOURCE, message)
    end

    --- A spawn-code list: a plain array of non-empty strings.
    ---
    --- Checked rather than trusted because every way of getting it wrong is
    --- silent. A number instead of a string hashes to a different value and
    --- simply never matches; a map instead of a list is skipped by ipairs, so
    --- half the entries do nothing; an empty string hashes to a real key that
    --- no vehicle has.
    local function checkSpawnList(value, key)
        if type(value) ~= 'table' then return end
        for index, name in pairs(value) do
            if type(index) ~= 'number' then
                bad(('Config.%s has a named key (%s).\n  Fix: write it as a plain list -- { "police3", "sheriff2" }.')
                    :format(key, tostring(index)))
            elseif type(name) ~= 'string' then
                bad(('Config.%s contains %s, which is not a spawn code.\n  Fix: spawn codes are strings -- { "police3" }, not { police3 }.')
                    :format(key, tostring(name)))
            elseif name == '' then
                bad(('Config.%s contains an empty string.\n  Fix: remove it, or write the spawn code.')
                    :format(key))
            end
        end
    end

    checkSpawnList(cfg.vehicleBlacklist, 'vehicleBlacklist')
    checkSpawnList(cfg.vehicleWhitelist, 'vehicleWhitelist')

    -- A model in both lists is not resolved silently in favour of either. The
    -- code answers "never sync" and says so here, because the alternative is an
    -- owner who whitelisted a vehicle watching it not sync with no explanation.
    if type(cfg.vehicleBlacklist) == 'table' and type(cfg.vehicleWhitelist) == 'table' then
        local blocked = {}
        for _, name in ipairs(cfg.vehicleBlacklist) do
            if type(name) == 'string' then blocked[name:lower()] = true end
        end
        for _, name in ipairs(cfg.vehicleWhitelist) do
            if type(name) == 'string' and blocked[name:lower()] then
                bad(('"%s" is in BOTH Config.vehicleBlacklist and Config.vehicleWhitelist.\n  Fix: the blacklist wins, so this vehicle will never sync. Remove it from one list.')
                    :format(name))
            end
        end
    end

    local classes = cfg.vehicleClasses
    if type(classes) == 'table' then
        if next(classes) == nil then
            bad(('Config.vehicleClasses is empty, so tSync will never touch anything.\n  Fix: { 18 } for Emergency, or stop the resource if that is what you meant.'))
        end
        for index, class in pairs(classes) do
            if type(index) ~= 'number' then
                bad(('Config.vehicleClasses has a named key (%s).\n  Fix: write it as a plain list -- { 18 }, or { 18, 19 }.')
                    :format(tostring(index)))
            elseif type(class) ~= 'number' or class ~= math.floor(class) then
                bad(('Config.vehicleClasses contains %s, which is not a whole number.\n  Fix: class numbers only -- 18 is Emergency.')
                    :format(tostring(class)))
            elseif class < 0 or class > MAX_VEHICLE_CLASS then
                bad(('Config.vehicleClasses contains %d, and GTA only defines 0-%d.\n  Fix: 18 is Emergency. The full list is at https://docs.fivem.net/natives/?_0x29439776AAA00A62')
                    :format(class, MAX_VEHICLE_CLASS))
            end
        end
    end

    return problems
end

--- Validate `Config` and print everything. Re-runnable: `tsync_diag` calls it.
--- @return boolean ok  false when the resource must not run
function tsyncConfigOk()
    local ok = tlib.config.check(Config, tsyncConfigSpec)

    local problems = crossChecks(Config)
    for _, message in ipairs(problems) do print('^1' .. message .. '^7') end
    if #problems > 0 then
        print(('^1[%s] %d configuration error(s) above. Fix them in %s and restart.^7')
            :format(RESOURCE, #problems, FILE))
    end

    return ok and #problems == 0
end

--- The boot verdict, read by client/cl_sync.lua.
---
--- A global boolean rather than the client calling `tsyncConfigOk()` itself:
--- both VMs load this file, and calling it per VM would print the same wall of
--- red twice -- an owner reading a duplicated error reasonably concludes there
--- are two of them.
tsyncConfigValid = tsyncConfigOk()
