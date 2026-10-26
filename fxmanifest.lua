fx_version 'cerulean'
game 'gta5'

name 'tSync'
description 'Emergency light sync for non-ELS vehicles'
author 'Tommy Johnston'
-- A second entry, not a rename: tlib.versioncheck grants the studio banner only
-- when the calling manifest carries an author equal to 'TIMMYG Studios'. Folder
-- name and opts.name do not count.
author 'TIMMYG Studios'
version '1.0.0'

lua54 'yes'

dependency 'tLib'

-- 1.0 is the first tLib carrying `config.check` and the `studios` versioncheck
-- provider. Do not lower it to start on an older tLib: a missing tLib module is
-- not nil but a truthy export proxy, so no `if tlib.config` guard catches it and
-- you get "attempt to index a function value" partway down a script instead of
-- "update tLib".
tlib_min_version '1.0'

shared_scripts {
    '@tLib/imports.lua',
    'config.lua',
    -- Immediately after the file it validates, and on both VMs even though only
    -- the client reads the values: an owner whose config is broken should see it
    -- whichever console they are watching.
    'shared/config-spec.lua',
}

-- The sync is entirely client-side by design. The reset is per-observer, so
-- there is nothing for a server to arbitrate and no net event to forge -- see
-- client/cl_sync.lua.
client_scripts {
    'client/cl_sync.lua',
}

-- No sv_access.lua, deliberately: an ACE gate needs a privileged action to gate
-- and tSync has none. An ACE object no code reads still reads, in a server.cfg
-- and in the docs, as a grant that is doing something.
server_scripts {
    'server/sv_version.lua',
}
