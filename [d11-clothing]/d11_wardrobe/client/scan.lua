-- /roupascan: reads what GTA's shop data says about every apparel item of the body you are wearing,
-- and sends it to the server (data/scan-<body>.json). Run once on a male and once on a female character;
-- tools/build_wardrobe.py turns the two scans into the creator's combinations (data/wardrobe-<body>.json).
--
-- Per item colour it records:
--   bad      the game says this drawable/texture is not a valid variation
--   forced   the components the shop forces with it (a top's correct arms, its undershirt)
--   variants the shop's variant components (the same piece open/closed, with another shirt...)
-- Items are named as whip_core names its cards and pictures: <collection>_<NNN> ('base' for the base game).

local COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local scanning = false

local function bodyOf(ped)
    local m = GetEntityModel(ped)
    if m == GetHashKey('mp_m_freemode_01') then return 'male' end
    if m == GetHashKey('mp_f_freemode_01') then return 'female' end
    return nil
end

local function keyOf(ped, base, comp, d)
    local name = GetPedCollectionNameFromDrawable(ped, comp, d)
    local idx = GetPedCollectionLocalIndexFromDrawable(ped, comp, d)
    if type(name) ~= 'string' or type(idx) ~= 'number' or idx < 0 then return nil end
    if name == '' or name == base then name = 'base' end
    return ('%s_%03d'):format(name, idx)
end

local function list(countFn, getFn, hash)
    local n = countFn(hash) or 0
    if n <= 0 then return nil end
    local out = {}
    for i = 0, n - 1 do
        local nameHash, enumValue, compType = getFn(hash, i)
        out[#out + 1] = { nameHash or 0, enumValue or -1, compType or -1 }
    end
    return out
end

local function scan()
    local ped = PlayerPedId()
    local body = bodyOf(ped)
    if not body then
        TriggerEvent('chat:addMessage', { args = { 'roupascan', 'Use um personagem freemode (masculino ou feminino).' } })
        return
    end
    scanning = true
    local base = GetPedCollectionName(ped, 0)
    local items, byHash = {}, {}
    local stats = { items = 0, colours = 0, bad = 0, forced = 0, variants = 0, shared = 0 }
    local tick = 0

    for _, comp in ipairs(COMPONENTS) do
        local slot = {}
        items[tostring(comp)] = slot
        for d = 0, GetNumberOfPedDrawableVariations(ped, comp) - 1 do
            local key = keyOf(ped, base, comp, d) or ('#%d'):format(d)
            local texCount = GetNumberOfPedTextureVariations(ped, comp, d)
            local rec = { d = d, n = texCount }
            for t = 0, texCount - 1 do
                stats.colours = stats.colours + 1
                if not IsPedComponentVariationValid(ped, comp, d, t) then
                    rec.bad = rec.bad or {}
                    rec.bad[#rec.bad + 1] = t
                    stats.bad = stats.bad + 1
                end
                local hash = GetHashNameForComponent(ped, comp, d, t)
                if hash and hash ~= 0 then
                    -- The first item with a shop name keeps it: added-on packs (ONX...) come after the game's own
                    -- items and can answer with the same name as one of them (the "no undershirt", say).
                    local h = tostring(hash)
                    if byHash[h] then stats.shared = stats.shared + 1 else byHash[h] = { comp, key, t } end
                    local f = list(GetShopPedApparelForcedComponentCount, GetForcedComponent, hash)
                    if f then rec.forced = rec.forced or {}; rec.forced[tostring(t)] = f; stats.forced = stats.forced + 1 end
                    local v = list(GetShopPedApparelVariantComponentCount, GetVariantComponent, hash)
                    if v then rec.variants = rec.variants or {}; rec.variants[tostring(t)] = v; stats.variants = stats.variants + 1 end
                end
                tick = tick + 1
                if tick % 400 == 0 then Wait(0) end
            end
            slot[key] = rec
            stats.items = stats.items + 1
        end
    end

    -- The drawable a forced/variant entry's enum points at, when its hash is not a shop item: keyed too.
    local keysByDrawable = {}
    for _, comp in ipairs(COMPONENTS) do
        local k = {}
        for d = 0, GetNumberOfPedDrawableVariations(ped, comp) - 1 do k[#k + 1] = keyOf(ped, base, comp, d) or '' end
        keysByDrawable[tostring(comp)] = k
    end

    local payload = json.encode({ body = body, made = GetCloudTimeAsInt(), stats = stats, items = items,
        byHash = byHash, keys = keysByDrawable })
    TriggerLatentServerEvent('d11_wardrobe:scan', 200000, body, payload)
    TriggerEvent('chat:addMessage', { args = { 'roupascan', ('%s: %d peças, %d cores, %d inválidas, %d com peças forçadas, %d com variantes. Enviando (%d KB)...')
        :format(body, stats.items, stats.colours, stats.bad, stats.forced, stats.variants, math.floor(#payload / 1024)) } })
    scanning = false
end

RegisterCommand('roupascan', function()
    if scanning then return end
    CreateThread(scan)
end, false)

RegisterNetEvent('d11_wardrobe:scanSaved', function(body, path, ok, why)
    TriggerEvent('chat:addMessage', { args = { 'roupascan', ok and ('%s salvo em %s'):format(body, path)
        or ('não salvou: %s'):format(tostring(why)) } })
end)
