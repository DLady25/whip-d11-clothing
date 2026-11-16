-- Clothing as items, client side: game number <-> collection + local index, dressing the ped, saving the look.
--
-- A piece keeps the COLLECTION and the number inside it ({ t = 'c'|'p', s = slot, col, i, tex }), not the global
-- number: that one moves when a clothing pack starts before another or the game build changes. 'base' = the base
-- game, where the local number is the global one (as in whip_core/client/appearance.lua).

local MODEL = { [joaat('mp_m_freemode_01')] = 'male', [joaat('mp_f_freemode_01')] = 'female' }

local function genderOf(ped) return MODEL[GetEntityModel(ped)] end

local function copy(t) return json.decode(json.encode(t)) end

--- Game number -> part. nil when the game cannot tell.
local function partOf(ped, t, s, d, tex)
    local name, idx
    if t == 'c' then
        name, idx = GetPedCollectionNameFromDrawable(ped, s, d), GetPedCollectionLocalIndexFromDrawable(ped, s, d)
    else
        name, idx = GetPedCollectionNameFromProp(ped, s, d), GetPedCollectionLocalIndexFromProp(ped, s, d)
    end
    if type(name) ~= 'string' or type(idx) ~= 'number' or idx < 0 then return nil end
    if name == '' or name == GetPedCollectionName(ped, 0) then name = 'base' end
    return { t = t, s = s, col = name, i = idx, tex = math.max(0, tex or 0) }
end

--- Part -> game number, or -1 when its collection is not loaded.
local function globalOf(ped, p)
    if p.col == 'base' then return p.i end
    local d
    if p.t == 'c' then d = GetPedDrawableGlobalIndexFromCollection(ped, p.s, p.col, p.i)
    else d = GetPedPropGlobalIndexFromCollection(ped, p.s, p.col, p.i) end
    return type(d) == 'number' and d or -1
end

--- The game number of a component's "undressed".
local function undressedOf(ped, gender, s)
    local item = Config.Undressed[gender][s]
    if not item then return 0 end
    return globalOf(ped, { t = 'c', s = s, col = item[1], i = item[2] })
end

--- What a saved look wears in a category: { parts, piece, tex } or false (nothing past "undressed").
local function pieceOfLook(ped, gender, app, cat)
    local parts, dressed = {}, false
    for _, s in ipairs(cat.c or {}) do
        local c = (app.components or {})[tostring(s)] or {}
        local d = tonumber(c.drawable) or 0
        if d ~= undressedOf(ped, gender, s) then dressed = true end
        local p = partOf(ped, 'c', s, d, tonumber(c.texture))
        if not p then return false end
        parts[#parts + 1] = p
    end
    for _, s in ipairs(cat.p or {}) do
        local pr = (app.props or {})[tostring(s)] or {}
        local d = tonumber(pr.drawable) or -1
        if d < 0 then return false end
        local p = partOf(ped, 'p', s, d, tonumber(pr.texture))
        if not p then return false end
        parts[#parts + 1] = p
        dressed = true
    end
    if not dressed then return false end
    local p = parts[1]
    local piece = p.col == 'base' and (L('Base game %d', 'Jogo base %d')):format(p.i) or ('%s %d'):format(p.col, p.i)
    return { parts = parts, piece = piece, tex = p.tex }
end

local function piecesOfLook(ped, gender, app)
    local out = {}
    for _, cat in ipairs(Config.Categories) do out[cat.key] = pieceOfLook(ped, gender, app, cat) end
    return out
end

--- A look's clothes as comparable text (components 1 and 3-11, props).
local function clothesOf(app)
    local out = {}
    for s = 1, 11 do
        if s ~= 2 then
            local c = (app.components or {})[tostring(s)] or {}
            out[#out + 1] = ('%s:%s'):format(c.drawable, c.texture)
        end
    end
    for _, s in ipairs({ 0, 1, 2, 6, 7 }) do
        local p = (app.props or {})[tostring(s)] or {}
        out[#out + 1] = ('%s:%s'):format(p.drawable, p.texture)
    end
    return table.concat(out, ',')
end

-- ============================================
-- The look: the saved one, with what we are about to save on top
-- ============================================

local look = nil          -- the last look we know (the saved one, or the one we sent to save)
local sent = nil          -- clothesOf() of the last one we sent to save
local lastSave = 0
local saveQueued = false

local function currentLook()
    if look then return look end
    local pd = exports.whip_core:GetPlayer() or {}
    local app = pd.metadata and pd.metadata.appearance
    return type(app) == 'table' and app.model and copy(app) or nil
end

-- WHIP takes one save every 2 s (saveAppearance's rateLimit): several quick changes become one.
local function saveSoon()
    if saveQueued then return end
    saveQueued = true
    CreateThread(function()
        local wait = 2100 - (GetGameTimer() - lastSave)
        if wait > 0 then Wait(wait) end
        saveQueued = false
        if not look then return end
        sent = clothesOf(look)
        lastSave = GetGameTimer()
        TriggerServerEvent('whip_core:server:saveAppearance', look)
    end)
end

-- ============================================
-- Dressing (the strip changed, or the login)
-- ============================================

--- `changed[cat]` = list of parts, or false (take off). Only those categories are dressed: a uniform put on by
--- another script (a job locker) stays in the others.
RegisterNetEvent('d11_clothing:dress', function(changed)
    local ped = PlayerPedId()
    local gender = genderOf(ped)
    local app = currentLook()
    if not gender or not app or type(changed) ~= 'table' then return end
    app.components, app.props = app.components or {}, app.props or {}
    local before = clothesOf(app)
    for _, cat in ipairs(Config.Categories) do
        local parts = changed[cat.key]
        if parts ~= nil then
            local bySlot = {}
            for _, p in ipairs(parts or {}) do bySlot[p.t .. p.s] = p end
            for _, s in ipairs(cat.c or {}) do
                local p = bySlot['c' .. s]
                local d, tex = p and globalOf(ped, p) or undressedOf(ped, gender, s), p and p.tex or 0
                if d < 0 then d, tex = undressedOf(ped, gender, s), 0 end   -- the piece's pack is not running
                SetPedComponentVariation(ped, s, d, tex, 0)
                app.components[tostring(s)] = { drawable = d, texture = tex }
            end
            for _, s in ipairs(cat.p or {}) do
                local p = bySlot['p' .. s]
                local d = p and globalOf(ped, p) or -1
                if d < 0 then
                    ClearPedProp(ped, s)
                    app.props[tostring(s)] = { drawable = -1, texture = 0 }
                else
                    SetPedPropIndex(ped, s, d, p.tex, true)
                    app.props[tostring(s)] = { drawable = d, texture = p.tex }
                end
            end
        end
    end
    look = app
    if clothesOf(app) ~= before then saveSoon() end
end)

-- The look was saved (WHIP's editor, a store, or us): if it was not us, the editor's clothes become items.
RegisterNetEvent('d11_clothing:check', function(app)
    if type(app) ~= 'table' or not app.model then return end
    local clothes = clothesOf(app)
    if clothes == sent then return end
    look = copy(app)
    sent = clothes
    local ped = PlayerPedId()
    local gender = genderOf(ped)
    if not gender or GetEntityModel(ped) ~= joaat(app.model) then return end
    TriggerServerEvent('d11_clothing:editor', gender, piecesOfLook(ped, gender, app))
end)

-- ============================================
-- Login
-- ============================================

local function announce()
    CreateThread(function()
        local ped = PlayerPedId()
        local gender = genderOf(ped)
        look, sent = nil, nil
        local app = currentLook()
        if not gender or not app then return end
        TriggerServerEvent('d11_clothing:ready', gender, piecesOfLook(ped, gender, app))
    end)
end

AddEventHandler('whip_core:player:loaded', announce)
AddEventHandler('whip_core:player:logout', function() look, sent = nil, nil end)

-- This resource restarted with the character in game.
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    local pd = exports.whip_core:GetPlayer() or {}
    if pd.charId then announce() end
end)
