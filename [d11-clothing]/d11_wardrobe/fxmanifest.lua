fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'd11_wardrobe'
author 'D11'
description 'Wardrobe data for the WHIP character editor: colours that really exist, and which pieces go together'
version '0.3.0'
license 'MIT'

-- The data is read by the editor page (whip_core, patch creator-wardrobe-d11) from
-- https://cfx-nui-d11_wardrobe/data/*.js (a <script>, so no CORS). Built by tools/build_pictures.py (pictures) and
-- tools/build_wardrobe.py (from the /roupascan results) and tools/build_gloves.py (gloves, from the arms pictures).
client_script 'client/scan.lua'
server_script 'server/scan.lua'

files {
    'data/textures-*.js',
    'data/wardrobe-*.js',
    'data/gloves-*.js',
}
