fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'd11_clothing'
author 'District 11 (D11)'
description 'Clothing as items on WHIP: the inventory\'s Equipped strip is what the character wears'
version '1.0.0'
license 'MIT'

-- 11 items d11_clothing_*, one Equipped slot per category. Needs Config.ContainerSlots.accessory = 16 in
-- whip_core/config.lua. Works on its own; with d11_stores, clothes bought in a store become items.
dependency 'whip_core'

shared_scripts {
    '@whip_core/lib/satellite.lua',
    'config.lua',
}
client_script 'client.lua'
server_script 'server.lua'

whip_requires '1.0'
