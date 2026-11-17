-- Estúdio de fotos do visual. O criador do whip_core abre (NUI open) e espera a resposta: a foto escolhida, ou
-- nada. Enquanto o estúdio está aberto esta página tem o foco; o criador continua aberto por baixo (câmera e
-- personagem são os dele) e se esconde sozinho.

local RES = GetCurrentResourceName()
-- Idioma: setr d11_locale en | pt-BR no server.cfg (padrao en), como os outros resources D11.
local LANG = GetConvar('d11_locale', 'en') == 'pt-BR' and 'pt-BR' or 'en'
local function L(en, pt) return LANG == 'pt-BR' and pt or en end
local aberto = false
local visualId = nil
local responder = nil      -- o callback do criador, respondido quando o estúdio fecha

-- As poses: as categorias da lista de emotes do WHIP que fazem sentido numa foto.
local CATEGORIAS = {
    { key = 'poses', label = L('Standing', 'Paradas') },
    { key = 'gestures', label = L('Gestures', 'Gestos') },
    { key = 'dance', label = L('Dances', 'Danças') },
}
local FORA = { 'sex' }   -- rótulos que não entram (poses sexuais)

local listaPoses = nil
local function poses()
    if listaPoses then return listaPoses end
    local por, out = {}, {}
    for _, c in ipairs(CATEGORIAS) do
        local cat = { key = c.key, label = c.label, poses = {} }
        por[c.key] = cat
        out[#out + 1] = cat
    end
    for _, e in ipairs((EmoteList or {}).emotes or {}) do
        local cat = por[e.category]
        local rotulo = tostring(e.label or e.cmd)
        local ok = cat and (e.dict or e.scenario)
        for _, f in ipairs(FORA) do if ok and rotulo:lower():find(f, 1, true) then ok = false end end
        if ok then cat.poses[#cat.poses + 1] = { cmd = e.cmd, label = rotulo, video = e.video } end
    end
    for _, c in ipairs(out) do table.sort(c.poses, function(a, b) return a.label < b.label end) end
    listaPoses = out
    return out
end

-- ============================================
-- O estúdio fica na SubUrban (Config.Ponto), numa dimensão só do player; ele volta para onde estava no fim.
-- ============================================
local origem = nil   -- { coords, heading, travado }
local indo = false   -- a ida ao estúdio ainda está acontecendo (a volta espera ela acabar)

local function esperarFade(saindo)
    local limite = GetGameTimer() + 1500
    while (saindo and not IsScreenFadedOut() or not saindo and not IsScreenFadedIn()) and GetGameTimer() < limite do Wait(0) end
end

local function levarPara(ped, x, y, z, h)
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)
    local limite = GetGameTimer() + 4000
    while (not HasCollisionLoadedAroundEntity(ped)) and GetGameTimer() < limite do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
end

local function irAoEstudio()
    local ped = PlayerPedId()
    origem = { coords = GetEntityCoords(ped), heading = GetEntityHeading(ped), travado = IsEntityPositionFrozen(ped) }
    DoScreenFadeOut(300)
    esperarFade(true)
    TriggerServerEvent('d11_photostudio:entrar')
    local p = Config.Ponto
    FreezeEntityPosition(ped, false)
    levarPara(ped, p.x, p.y, p.z, p.w)
    -- O interior da loja: espera ele aparecer (as lojas do jogo já estão no mapa, só precisam carregar).
    local limite = GetGameTimer() + 3000
    while GetInteriorFromEntity(ped) == 0 and GetGameTimer() < limite do Wait(0) end
    local interior = GetInteriorFromEntity(ped)
    if interior ~= 0 then
        PinInteriorInMemory(interior)
        while not IsInteriorReady(interior) and GetGameTimer() < limite do Wait(0) end
    end
    FreezeEntityPosition(ped, true)
    Wait(250)
    DoScreenFadeIn(400)
end

local function voltarDoEstudio()
    local o = origem
    origem = nil
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    esperarFade(true)
    FreezeEntityPosition(ped, false)
    if o then levarPara(ped, o.coords.x, o.coords.y, o.coords.z, o.heading) end
    TriggerServerEvent('d11_photostudio:sair')
    FreezeEntityPosition(ped, o and o.travado or false)
    Wait(250)
    DoScreenFadeIn(400)
end

-- A câmera do criador, pelo export do whip_core (patch creator-photostudio): a página do estúdio não alcança os
-- callbacks da página do whip_core. lock, stage, preset, yaw, turn, pan, orbitX, zoom.
-- Declarada ANTES de fechar() e do 'open', que a usam: um `local function` só existe da linha dele para baixo
-- (antes daqui era a global `camera`, nil: "attempt to call a nil value (global 'camera')").
local function camera(o) return pcall(function() return exports.whip_core:CreatorCamera(o) end) end

local function fechar(foto)
    if not aberto then return end
    aberto = false
    pcall(function() exports.whip_core:CancelEmote() end)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    local cb = responder
    responder, visualId = nil, nil
    camera({ lock = false })   -- a câmera volta a seguir o personagem
    -- O criador só volta depois que o player voltou para onde estava.
    CreateThread(function()
        while indo do Wait(0) end
        if origem then voltarDoEstudio() end
        if cb then cb({ ok = true, photo = foto }) end
    end)
end

-- O criador pede o estúdio para um visual salvo. Respondido só quando o estúdio fecha.
RegisterNUICallback('open', function(data, cb)
    local id = tonumber(data and data.id)
    if aberto or not id then cb({ ok = false }) return end
    aberto, visualId, responder = true, math.floor(id), cb
    local nome = type(data.name) == 'string' and data.name:sub(1, 40) or ''
    CreateThread(function()
        indo = true
        irAoEstudio()
        indo = false
        if not aberto then return end   -- fechou (morreu, deslogou) enquanto ia: o fechar já traz de volta
        SendNUIMessage({ action = 'open', name = nome, categories = poses(), lang = LANG })
        SetNuiFocus(true, true)
        -- O personagem no centro, a câmera travada no mundo (girar mexe só nele), o corpo inteiro com folga.
        camera({ stage = 0.0, lock = true, preset = 'body', yaw = 180.0 })
        SetTimeout(150, function() if aberto then camera({ zoom = 5 }) end end)
    end)
end)

RegisterNUICallback('camera', function(data, cb)
    if aberto and type(data) == 'table' then camera(data) end
    cb({ ok = true })
end)

-- Girar o personagem (a câmera fica travada no mundo: só ele gira na frente do fundo).
RegisterNUICallback('girar', function(data, cb)
    local g = tonumber(type(data) == 'table' and data.graus) or 0
    if aberto and g ~= 0 and g > -90 and g < 90 then
        local ped = PlayerPedId()
        SetEntityHeading(ped, (GetEntityHeading(ped) + g) % 360.0)
    end
    cb({ ok = true })
end)

-- R: de frente para a câmera de novo (a direção do ponto do estúdio).
RegisterNUICallback('frente', function(_, cb)
    if aberto then SetEntityHeading(PlayerPedId(), Config.Ponto.w + 0.0) end
    cb({ ok = true })
end)

RegisterNUICallback('pose', function(data, cb)
    local cmd = type(data) == 'table' and data.cmd
    local ok = false
    if type(cmd) == 'string' and cmd ~= '' then
        ok = pcall(function() exports.whip_core:PlayEmote(cmd) end)
    else
        ok = pcall(function() exports.whip_core:CancelEmote() end)
    end
    cb({ ok = ok })
end)

-- A foto da tela, só o jogo (sem nenhuma página). A página recorta a moldura.
RegisterNUICallback('shoot', function(_, cb)
    CreateThread(function()
        local img, why = exports.whip_core:TakeScreenshot({ format = 'png' })
        cb({ ok = type(img) == 'string', shot = img or nil, why = why })
    end)
end)

RegisterNUICallback('save', function(data, cb)
    local foto = type(data) == 'table' and data.photo
    if not aberto or type(foto) ~= 'string' or not foto:match('^data:image/webp;base64,') or #foto > 600000 then
        cb({ ok = false })
        return
    end
    TriggerLatentServerEvent('d11_photostudio:salvar', 400000, visualId, foto)
    cb({ ok = true })
    fechar(foto)
end)

RegisterNUICallback('close', function(_, cb)
    cb({ ok = true })
    fechar(nil)
end)

-- As fotos dos visuais, para os cartões do criador: { [id] = data URL }. O criador pergunta ao abrir.
local pedidos, proximo = {}, 0
RegisterNUICallback('photos', function(data, cb)
    local ids = {}
    for _, v in ipairs(type(data) == 'table' and type(data.ids) == 'table' and data.ids or {}) do
        local n = tonumber(v)
        if n and #ids < 50 then ids[#ids + 1] = math.floor(n) end
    end
    proximo = proximo + 1
    pedidos[proximo] = cb
    local meu = proximo
    TriggerServerEvent('d11_photostudio:pedir', meu, ids)
    SetTimeout(10000, function()
        if pedidos[meu] then pedidos[meu]({ photos = {} }); pedidos[meu] = nil end
    end)
end)

RegisterNetEvent('d11_photostudio:fotos', function(id, fotos)
    local cb = pedidos[id]
    pedidos[id] = nil
    if cb then cb({ photos = type(fotos) == 'table' and fotos or {} }) end
end)

-- Morreu, deslogou ou o resource parou com o estúdio aberto: fecha sem foto.
AddEventHandler('whip_core:player:died', function() fechar(nil) end)
AddEventHandler('whip_core:player:logout', function() fechar(nil) end)
AddEventHandler('onResourceStop', function(res)
    if res ~= RES or not aberto then return end
    SetNuiFocus(false, false)
    local o, ped = origem, PlayerPedId()
    if o then
        FreezeEntityPosition(ped, o.travado)
        SetEntityCoordsNoOffset(ped, o.coords.x, o.coords.y, o.coords.z, false, false, false)
        SetEntityHeading(ped, o.heading)
        TriggerServerEvent('d11_photostudio:sair')
    end
    DoScreenFadeIn(0)
end)

-- A posição atual como vector4, para trocar Config.Ponto (só lê).
RegisterCommand(Config.ComandoPonto or 'fotospot', function()
    local ped = PlayerPedId()
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local txt = ('vector4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, h)
    print('[d11_photostudio] Config.Ponto = ' .. txt)
    TriggerEvent('chat:addMessage', { args = { 'fotospot', txt } })
end, false)
