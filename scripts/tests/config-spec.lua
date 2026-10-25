-- shared/config-spec.lua against the config file it validates.
--
-- Loads tLib's REAL config module out of the sibling directory rather than
-- stubbing it. A stubbed validator would assert that this suite agrees with
-- itself; what has to hold is that the file we ship passes the spec tLib
-- actually runs.

local ROOT = (arg[0] or ''):match('^(.*)scripts[/\\]tests[/\\]') or './'
local function path(p) return ROOT .. p end

function GetCurrentResourceName() return 'tSync' end

-- Everything printed by config.check is expected output, not a result. Captured
-- so a passing run is quiet and a failing one still has the text to show.
local printed = {}
local realPrint = print
print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(parts, '\t')
end

tlib = { config = dofile(path('../tLib/shared/imports/config/shared.lua')) }

dofile(path('config.lua'))
local shipped = Config
dofile(path('shared/config-spec.lua'))

print = realPrint

local checks = 0
local function fail(message)
    for _, text in ipairs(printed) do realPrint('    ' .. text) end
    error(message, 2)
end
local function check(value, message)
    checks = checks + 1
    if not value then fail(message) end
end

-- ── The file we ship passes its own spec ───────────────────────────────────
--
-- The one assertion that has to hold forever. A spec that rejects the shipped
-- config would greet every new install with a wall of red on a file the owner
-- has not touched, which is worse than no validation at all.

check(tsyncConfigValid, 'config.lua does not pass shared/config-spec.lua')

local report = tlib.config.validate(shipped, tsyncConfigSpec)
check(#report.errors == 0, #report.errors .. ' error(s) on the shipped config')

-- No warnings either, which is stronger than it looks: an unknown key warns, so
-- this is also the assertion that the spec's key set and config.lua's key set
-- have not drifted apart in either direction.
check(#report.warnings == 0, #report.warnings .. ' warning(s) on the shipped config')

-- ── The defaults match the file, literal for literal ───────────────────────
--
-- `default =` is only consulted for a key the owner DELETED, so a default that
-- disagrees with config.lua is invisible until someone deletes that key and
-- silently gets different behaviour from the person who kept it.

for key, rule in pairs(tsyncConfigSpec.keys) do
    if rule.default ~= nil then
        check(shipped[key] == rule.default,
            ('Config.%s ships as %s but the spec defaults to %s')
                :format(key, tostring(shipped[key]), tostring(rule.default)))
    end
end

-- ── vehicleClasses, which the per-key rules cannot reach ───────────────────
--
-- Each of these is a value that type-checks and then does nothing. They are the
-- reason crossChecks exists, so each one is asserted to be REJECTED rather than
-- trusting that writing the code was enough.

local function rejects(value, what)
    local saved = Config.vehicleClasses
    Config.vehicleClasses = value
    local quiet = {}
    local wasPrint = print
    print = function(...) quiet[#quiet + 1] = select(1, ...) end
    local ok = tsyncConfigOk()
    print = wasPrint
    Config.vehicleClasses = saved
    check(not ok, ('vehicleClasses = %s should be rejected (%s)'):format(what, what))
end

rejects({}, 'empty, so nothing would ever sync')
rejects({ 18.5 }, 'not a whole number')
rejects({ 99 }, 'outside the 0-22 GTA defines')
rejects({ -1 }, 'negative')
rejects({ emergency = 18 }, 'a named key rather than a list')

-- And the shipped value is still accepted after all that poking, which is the
-- control on the helper above: if `rejects` left Config in a bad state the
-- suite would be asserting against a tree it had broken itself.
check(tsyncConfigOk(), 'the shipped vehicleClasses is still accepted')

realPrint(('PASS: %d config-spec checks'):format(checks))
