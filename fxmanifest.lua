fx_version 'cerulean'
game 'gta5'

name 'tSync'
description 'Emergency light sync for non-ELS vehicles'
author 'Tommy Johnston'
-- Second author entry, not a rename of the first: tlib.versioncheck grants the
-- studio banner only when the CALLING resource's manifest carries an author
-- equal to 'TIMMYG Studios'. Folder name and opts.name do not count.
author 'TIMMYG Studios'
version '1.0.0'

lua54 'yes'

dependency 'tLib'

-- 1.0 is the first tLib carrying `config.check`, which validates config.lua at
-- boot, and the `studios` versioncheck provider below. Do not lower this line
-- to start on an older tLib: a missing module is not nil, it is a truthy export
-- proxy, so no `if tlib.config` guard catches it and you get "attempt to index a
-- function value" partway down a script instead of "update tLib".
tlib_min_version '1.0'


shared_scripts {
    '@tLib/imports.lua',
    'config.lua',
    -- Immediately after the file it validates. Both VMs, even though only the
    -- client reads the values: the server prints the same verdict, and an owner
    -- whose config is broken should see it whichever console they are watching.
    'shared/config-spec.lua',
}

-- THE WHOLE FEATURE IS CLIENT-SIDE, and that is the design rather than an
-- omission. The phase reset is a per-observer visual alignment -- it re-phases
-- what THIS client draws, including vehicles it does not own -- so there is
-- nothing for a server to arbitrate and no net event to forge. Every client
-- lands on the same instant because they share GetNetworkTimeAccurate(), not
-- because anything tells them to. See client/cl_sync.lua.
client_scripts {
    'client/cl_sync.lua',
}

-- sv_version.lua alone. There is deliberately no sv_access.lua: an ACE gate
-- needs a privileged action to gate, tSync has none, and an ACE object no code
-- reads is worse than none -- in a server.cfg and in the docs it reads as a
-- grant that is doing something.
server_scripts {
    'server/sv_version.lua',
}

-- No `escrow_ignore`, and do not add one. tSync is free and is never
-- escrow-packed, so every file here is already readable; the block only carves
-- exceptions out of an encrypted build, and declaring one would assert a build
-- that does not exist. See LICENSE.
