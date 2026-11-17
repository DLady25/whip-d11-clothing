fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'd11_stores'
author 'District 11 (D11)'
description 'Clothing store, barber, tattoo studio and plastic surgeon on WHIP\'s character editor, with prices and a settings page'
version '1.1.0'
license 'MIT'

-- Each store type opens WHIP's character editor on only the tabs it unlocks and charges for what changed.
-- whip_core 1.2.0 or newer: its own store checkout (EditAppearance), nothing to patch.
-- whip_core 1.0.1 / 1.1.x: the appearance-policy patch in whip_core-patches/ (a cart with a line per item).
-- Settings page: /whip -> Settings -> Clothing stores.
dependency 'whip_core'

shared_scripts {
    '@whip_core/lib/satellite.lua',
    'config.lua',
    'settings.lua',
}
client_script 'client.lua'
server_script 'server.lua'

whip_requires '1.0'
