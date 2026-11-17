fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'd11_photostudio'
author 'D11'
description 'Estúdio de fotos do visual no criador do WHIP: pose, ângulo e a foto real do personagem no cartão do visual'
version '1.0.0'
license 'MIT'

-- Aberto pelo criador do whip_core (patch creator-photostudio-d11): o botão "Foto do visual" chama
-- https://d11_photostudio/open e espera o estúdio fechar. A câmera é a do criador (switchCamera/camInput do
-- whip_core), a foto é o TakeScreenshot do whip_core (só o jogo, sem interface) e as poses são a lista de
-- emotes do WHIP (shared/emote_list.lua, GPL 3.0, carregada daqui sem cópia). A foto é tirada na SubUrban de
-- Del Perro (Config.Ponto), numa dimensão só do player.
dependency 'whip_core'

shared_scripts {
    '@whip_core/shared/emote_list.lua',
    'config.lua',
}
client_script 'client.lua'
server_script 'server.lua'

ui_page 'web/index.html'
files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}
