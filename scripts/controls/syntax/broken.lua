-- Negative control for check:syntax: Lua that CANNOT PARSE.
--
-- Excluded from `bun run check:syntax`'s glob by name, with the reason written at
-- the exclusion. Driven only by `SYNTAX_CONTROL=1 bun run check:syntax`, which
-- points the checker here and REQUIRES exit 1.
--
-- A missing `end`, because that is the error that actually happens: invisible to
-- `bun test`, which loads no Lua, and to the fengari suites, which only load the
-- files they are oracles for.
--
-- ⚠️ Do not "fix" this file. It is red on purpose, and deleting it does not make
-- the gate pass — it makes the gate's control fail.
local function tsyncControlBrokenOnPurpose(a, b)
    if a > b then
        return a
    -- no `end` for the `if`, and no `end` for the function
