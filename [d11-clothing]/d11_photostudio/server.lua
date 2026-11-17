-- As fotos dos visuais, uma por visual de cada personagem: photos/<personagem>_<visual>.txt (o data URL webp).
local RES = GetCurrentResourceName()
local MAX = 600000

local function personagem(src)
    local ok, id = pcall(function() return exports.whip_core:GetCharId(src) end)
    if not ok or id == nil then return nil end
    id = tostring(id):gsub('[^%w_-]', '')
    return id ~= '' and id or nil
end

local function arquivo(char, visual) return ('photos/%s_%d.txt'):format(char, visual) end

local function idValido(v) return type(v) == 'number' and v == math.floor(v) and v >= 0 and v <= 99999999 end

RegisterNetEvent('d11_photostudio:salvar', function(visual, foto)
    local src = source
    local char = personagem(src)
    if not char or not idValido(visual) then return end
    if type(foto) ~= 'string' or #foto > MAX or not foto:match('^data:image/webp;base64,[%w%+/=]+$') then
        print(('[d11_photostudio] photo refused from %s (format or size)'):format(src))
        return
    end
    if not SaveResourceFile(RES, arquivo(char, visual), foto, -1) then
        print(('[d11_photostudio] could not save %s (does the photos folder exist?)'):format(arquivo(char, visual)))
    end
end)

RegisterNetEvent('d11_photostudio:pedir', function(pedido, ids)
    local src = source
    local char = personagem(src)
    local fotos = {}
    if char and type(ids) == 'table' then
        for i, v in ipairs(ids) do
            if i > 50 then break end
            if idValido(v) then
                local foto = LoadResourceFile(RES, arquivo(char, v))
                if foto and foto ~= '' then fotos[tostring(v)] = foto end
            end
        end
    end
    TriggerLatentClientEvent('d11_photostudio:fotos', src, 400000, pedido, fotos)
end)

-- ============================================
-- A dimensão do estúdio
-- ============================================
-- Enquanto fotografa, o player fica numa dimensão só dele (Config.DimensaoBase + id). Para isso não virar um
-- jeito de andar invisível pela cidade, quem se afastar do ponto do estúdio volta para a dimensão de antes.
local voltar = {}   -- [src] = a dimensão de antes
local LONGE = 30.0

local function sair(src)
    local b = voltar[src]
    if b == nil then return end
    voltar[src] = nil
    SetPlayerRoutingBucket(src, b)
end

RegisterNetEvent('d11_photostudio:entrar', function()
    local src = source
    if voltar[src] ~= nil then return end
    voltar[src] = GetPlayerRoutingBucket(src)
    local b = Config.DimensaoBase + src
    SetRoutingBucketPopulationEnabled(b, false)
    SetPlayerRoutingBucket(src, b)
end)

RegisterNetEvent('d11_photostudio:sair', function() sair(source) end)
AddEventHandler('playerDropped', function() voltar[source] = nil end)

CreateThread(function()
    local p = Config.Ponto
    local ponto = vector3(p.x, p.y, p.z)
    while true do
        Wait(5000)
        for src in pairs(voltar) do
            local ped = GetPlayerPed(src)
            if ped == 0 or #(GetEntityCoords(ped) - ponto) > LONGE then
                print(('[d11_photostudio] %s walked away from the studio: back to their own routing bucket'):format(src))
                sair(src)
            end
        end
    end
end)
