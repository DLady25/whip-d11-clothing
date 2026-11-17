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

-- ============================================
-- Gloves: an "arm" (component 3) with a gloved hand (data/gloves-<body>.json)
-- ============================================
-- GTA has no glove slot: a glove is an arm with the hand covered. For each base-game arm the data says its type (the
-- bare arm of the same shape), whether it is a glove and which glove (the style: the same glove on every type). The
-- Shirt keeps the bare arm of its type; the Gloves item keeps the glove, worn on the shirt's arm type. An arm the
-- data does not know (a clothing pack's) stays with the Shirt.

local glovesCache = {}   -- [gender] = data or false
local function glovesOf(gender)
    if glovesCache[gender] ~= nil then return glovesCache[gender] or nil end
    local raw = LoadResourceFile(GetCurrentResourceName(), ('data/gloves-%s.json'):format(gender))
    local ok, d = pcall(json.decode, raw or '')
    glovesCache[gender] = ok and type(d) == 'table' and d or false
    return glovesCache[gender] or nil
end

local armMaps = {}   -- [gender] = { byKey = { ['male_heist_011'] = 74 }, byD = { [74] = 'male_heist_011' } }
local function armMap(ped, gender)
    if armMaps[gender] then return armMaps[gender] end
    local m = { byKey = {}, byD = {} }
    for d = 0, GetNumberOfPedDrawableVariations(ped, 3) - 1 do
        local p = partOf(ped, 'c', 3, d, 0)
        if p then
            local k = ('%s_%03d'):format(p.col:lower(), p.i)
            m.byKey[k], m.byD[d] = d, k
        end
    end
    armMaps[gender] = m
    return m
end

--- What an arm is: { type, glove, style } (type = the bare arm's key), or nil when the data does not know it.
local function armInfo(ped, gender, d)
    local data = glovesOf(gender)
    if not data or type(d) ~= 'number' or d < 0 then return nil end
    local k = armMap(ped, gender).byD[d]
    if not k then return nil end
    if data.types and data.types[k] then return { type = k, glove = false } end
    local a = data.arms and data.arms[k]
    if not a then return nil end
    return { type = a.type, glove = a.glove == true, style = a.style }
end

--- The game arm of type `armType` wearing glove `style` (nil = bare), or -1.
local function armOf(ped, gender, armType, style)
    local data = glovesOf(gender)
    if not data or not armType then return -1 end
    local k = armType
    if style ~= nil then k = ((data.styles or {})[tostring(style)] or {})[armType] end
    return k and armMap(ped, gender).byKey[k] or -1
end

--- What a saved look wears in a category: { parts, piece, tex } or false (nothing past "undressed").
local function pieceOfLook(ped, gender, app, cat)
    local parts, dressed = {}, false
    for _, s in ipairs(cat.c or {}) do
        local c = (app.components or {})[tostring(s)] or {}
        local d = tonumber(c.drawable) or 0
        local tex = tonumber(c.texture)
        if s == 3 then
            -- A gloved arm becomes the Gloves item; the Shirt keeps the bare arm of the same type.
            local info = armInfo(ped, gender, d)
            if cat.gloves then
                if not (info and info.glove) then return false end
                dressed = true
            elseif info and info.glove and info.type then
                local bare = armOf(ped, gender, info.type, nil)
                if bare >= 0 then d, tex = bare, 0 end
            end
        end
        if not cat.gloves and d ~= undressedOf(ped, gender, s) then dressed = true end
        local p = partOf(ped, 'c', s, d, tex)
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
    -- The arm on the body now: the shirt's (bare) arm, and the glove over it, if any.
    local armNow = app.components['3'] or {}
    local ad, atex = tonumber(armNow.drawable) or undressedOf(ped, gender, 3), tonumber(armNow.texture) or 0
    local glove = nil   -- { d, tex }
    local info = armInfo(ped, gender, ad)
    if info and info.glove then
        glove = { d = ad, tex = atex }
        local bare = armOf(ped, gender, info.type, nil)
        ad, atex = bare >= 0 and bare or undressedOf(ped, gender, 3), 0
    end
    local armTouched = false
    for _, cat in ipairs(Config.Categories) do
        local parts = changed[cat.key]
        if parts ~= nil then
            local bySlot = {}
            for _, p in ipairs(parts or {}) do bySlot[p.t .. p.s] = p end
            for _, s in ipairs(cat.c or {}) do
                local p = bySlot['c' .. s]
                local d, tex = p and globalOf(ped, p) or undressedOf(ped, gender, s), p and p.tex or 0
                if d < 0 then d, tex = undressedOf(ped, gender, s), 0 end   -- the piece's pack is not running
                if s == 3 then
                    armTouched = true
                    if cat.gloves then
                        glove = p and { d = d, tex = tex } or nil
                    else
                        ad, atex = d, tex
                        local i2 = armInfo(ped, gender, d)   -- an older shirt with the glove inside
                        if i2 and i2.glove then
                            if not glove then glove = { d = d, tex = tex } end
                            local bare = armOf(ped, gender, i2.type, nil)
                            ad, atex = bare >= 0 and bare or undressedOf(ped, gender, 3), 0
                        end
                    end
                else
                    SetPedComponentVariation(ped, s, d, tex, 0)
                    app.components[tostring(s)] = { drawable = d, texture = tex }
                end
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
    if armTouched then
        local d, tex = ad, atex
        if glove and glove.d >= 0 then
            local baseType = (armInfo(ped, gender, ad) or {}).type
            local gi = armInfo(ped, gender, glove.d)
            local gd = (gi and gi.style ~= nil and baseType) and armOf(ped, gender, baseType, gi.style) or -1
            if gd >= 0 then d, tex = gd, glove.tex
            elseif gi and gi.type == baseType then d, tex = glove.d, glove.tex end
            -- Else this glove has no version for these arms (long sleeves, one-piece arms): bare hands.
        end
        SetPedComponentVariation(ped, 3, d, tex, 0)
        app.components['3'] = { drawable = d, texture = tex }
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
