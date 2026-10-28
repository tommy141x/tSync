fx_version 'cerulean'
game 'gta5'

name 'tSync'
description 'Emergency light sync for non-ELS vehicles'
author 'Tommy Johnston'
-- tlib.versioncheck looks for an author equal to 'TIMMYG Studios'; nothing else
-- it can read identifies the resource as ours.
author 'TIMMYG Studios'
version '1.0'

lua54 'yes'

dependency 'tLib'

-- 1.0 is the first tLib with `config.check` and the `studios` versioncheck
-- provider. A missing tLib module is a truthy export proxy, not nil, so on an
-- older tLib no guard catches it and you get "attempt to index a function
-- value" partway down a script instead of "update tLib".
tlib_min_version '1.0'

shared_scripts {
    '@tLib/imports.lua',
    'config.lua',
    -- After the file it validates, and on both VMs so a broken config is
    -- reported in whichever console the owner is watching.
    'shared/config-spec.lua',
}

client_scripts {
    'client/cl_sync.lua',
}

server_scripts {
    'server/sv_version.lua',
}
