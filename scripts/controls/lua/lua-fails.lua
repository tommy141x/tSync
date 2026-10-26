-- Negative control for the Lua gate: an assertion that is FALSE.
--
-- Outside `bun run test:lua`'s glob on purpose, or the gate would be permanently
-- red. Driven only by `LUA_CONTROL=1 bun run test:lua`, which REQUIRES a non-zero
-- exit from this file.
--
-- A plain `assert`, which is how every real suite reports: if this stops failing,
-- the reporting mechanism the suites share has broken, not this file.
assert(1 == 2, 'the Lua gate control: this assertion is false on purpose')
