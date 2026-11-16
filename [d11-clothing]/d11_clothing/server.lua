-- Clothing as items. What is worn is the inventory's "Equipped" strip (slots 6-16, one per category): WHIP keeps,
-- weighs and logs it; this only decides what goes on the body.
--
--   strip changed (drag, use, give, drop)   -> the client dresses only the changed categories and saves the look
--   editor saved (store, /charedit, admin)  -> what changed in the look becomes an item in its slot; the old one goes
--   first login with this resource           -> the saved look's clothes become items (once per character)
--   later logins                             -> the strip rules: the body wears what is in it

local CAT, SLOT_OF, CAT_OF_SLOT, CAT_OF_ITEM = {}, {}, {}, {}
for i, c in ipairs(Config.Categories) do
    local slot = Config.FirstSlot + i - 1
    CAT[c.key], SLOT_OF[c.key], CAT_OF_SLOT[slot] = c, slot, c.key
    CAT_OF_ITEM['d11_clothing_' .. c.key] = c.key
end

local CONVERTED = 'd11_clothing'   -- character metadata: the saved look's clothes already became items
local BODY = { male = L('Male', 'Masculino'), female = L('Female', 'Feminino') }

local function itemOf(cat) return 'd11_clothing_' .. cat end
local function strip(src, slot) return { kind = 'player', id = src, sub = 'accessory', slot = slot } end
local function pockets(src) return { kind = 'player', id = src, sub = 'player' } end
local function tell(src, msg, kind) exports.whip_core:NotifyPlayer(src, msg, kind or 'error') end

--- A list of parts as comparable text ('' = no piece).
local function signature(parts)
    if type(parts) ~= 'table' then return '' end
    local out = {}
    for _, p in ipairs(parts) do out[#out + 1] = ('%s%d:%s:%d:%d'):format(p.t, p.s, p.col, p.i, p.tex) end
    return table.concat(out, '|')
end

-- [src] = { gender, worn = { [cat] = signature the body has } }
local state = {}

--- The pieces in the strip, by category.
local function readStrip(src)
    local out = {}
    local s = exports.whip_core:StoreRead({ kind = 'player', id = src, sub = 'accessory' })
    if not s then return out end
    for slot, it in pairs(s.items or {}) do
        local cat = CAT_OF_SLOT[tonumber(slot)]
        if cat and it.item == itemOf(cat) then out[cat] = it end
    end
    return out
end

-- ============================================
-- What the client sends: checked here
-- ============================================

local function int(v, max) return type(v) == 'number' and v == math.floor(v) and v >= 0 and v <= max end

--- { parts, piece, tex } for a category, or false (no piece), or nil if it came in wrong.
local function cleanPiece(cat, v)
    if v == false then return false end
    if type(v) ~= 'table' or type(v.parts) ~= 'table' then return nil end
    local c, accepted = CAT[cat], {}
    for _, s in ipairs(c.c or {}) do accepted['c' .. s] = true end
    for _, s in ipairs(c.p or {}) do accepted['p' .. s] = true end
    local parts = {}
    for n, p in ipairs(v.parts) do
        if n > 4 or type(p) ~= 'table' then return nil end
        if not accepted[tostring(p.t) .. tostring(p.s)] then return nil end
        if type(p.col) ~= 'string' or #p.col > 64 or not p.col:match('^[%w_]+$') then return nil end
        if not int(p.i, 4095) or not int(p.tex, 255) then return nil end
        parts[n] = { t = p.t, s = p.s, col = p.col, i = p.i, tex = p.tex }
    end
    if #parts == 0 then return nil end
    local piece = type(v.piece) == 'string' and v.piece:sub(1, 40) or c.label
    return { parts = parts, piece = piece, tex = parts[1].tex }
end

local function metadataOf(gender, v)
    local p = v.parts[1]
    local dir = p.t == 'c' and ('c' .. p.s) or ('p' .. p.s)
    return {
        gender = gender,
        body = BODY[gender],
        piece = v.piece,
        colour = tostring(v.tex),
        parts = v.parts,
        -- The real picture (whip_core's clothing photos), for an inventory renderer that reads it (d11_inventory).
        foto = ('%s/%s/%s/%03d/%02d'):format(gender, dir, p.col, p.i, p.tex),
    }
end

-- ============================================
-- Strip -> body
-- ============================================

local busy = {}

local function sync(src)
    local e = state[src]
    if not e then return end
    if busy[src] then busy[src] = 'again' return end
    busy[src] = true
    local pieces, changed = readStrip(src), {}
    for _, c in ipairs(Config.Categories) do
        local it = pieces[c.key]
        local meta = it and it.metadata or {}
        if it and meta.gender ~= e.gender then
            -- A piece for the other body: back to the pockets (or it stays, if it does not fit, without dressing).
            exports.whip_core:StoreMove(strip(src, SLOT_OF[c.key]), pockets(src), { reason = 'd11_clothing: other body' })
            tell(src, L('That piece is for the other body.', 'Essa peça é de outro corpo.'))
            it = nil
        end
        local parts = it and meta.parts or false
        local sig = signature(parts)
        if e.worn[c.key] ~= sig then
            e.worn[c.key] = sig
            changed[c.key] = parts
        end
    end
    if next(changed) then TriggerClientEvent('d11_clothing:dress', src, changed) end
    local again = busy[src] == 'again'
    busy[src] = nil
    if again then sync(src) end
end

AddEventHandler('whip_core:inventory:changed', function(d)
    if type(d) == 'table' and d.source then sync(d.source) end
end)

-- ============================================
-- Look -> strip (editor saved, first login)
-- ============================================

--- `current[cat]` = { parts, piece, tex } or false, from the saved look. Makes the strip match it.
--- Returns false if some piece did not get into the strip.
local function reconcile(src, current)
    local e = state[src]
    local pieces = readStrip(src)
    local allIn = true
    busy[src] = true   -- the swaps below fire inventory:changed: the body already looks like this
    for _, c in ipairs(Config.Categories) do
        local target = cleanPiece(c.key, current[c.key])
        if target ~= nil then
            local it, slot = pieces[c.key], SLOT_OF[c.key]
            local sigTarget = signature(target and target.parts)
            local sigItem = it and signature(it.metadata and it.metadata.parts) or ''
            if it and (it.metadata or {}).gender ~= e.gender then
                -- The body changed in the editor: the old piece does not fit, but it is theirs. To the pockets.
                exports.whip_core:StoreMove(strip(src, slot), pockets(src), { reason = 'd11_clothing: other body' })
                it, sigItem = nil, ''
            end
            local worn = sigTarget
            if sigTarget ~= sigItem then
                if it then exports.whip_core:StoreTake(strip(src, slot), nil, 'd11_clothing: changed in the editor') end
                if target then
                    local ok, why = exports.whip_core:StoreGive(strip(src, slot), itemOf(c.key), 1,
                        metadataOf(e.gender, target), 'd11_clothing: put on in the editor')
                    if not ok then
                        print(('[d11_clothing] %s: %s did not fit in the strip: %s'):format(src, c.key, tostring(why)))
                        -- The body still wears it, but the slot is empty: note it as empty, or the next strip change
                        -- would "take off" this category too.
                        worn, allIn = '', false
                    end
                end
            end
            e.worn[c.key] = worn
        end
    end
    busy[src] = nil
    return allIn
end

local function validGender(g) return g == 'male' or g == 'female' end

-- Login (and a restart of this resource with the player in game).
RegisterNetEvent('d11_clothing:ready', function(gender, current)
    local src = source
    if not validGender(gender) or type(current) ~= 'table' then return end
    state[src] = { gender = gender, worn = {} }
    if not exports.whip_core:GetPlayerMetadata(src, CONVERTED) then
        -- Marked converted only if every piece got in: otherwise the next login tries again.
        if reconcile(src, current) then exports.whip_core:SetPlayerMetadata(src, CONVERTED, 1) end
        return
    end
    -- The strip rules: the body wears exactly what is in it.
    local pieces, all = readStrip(src), {}
    for _, c in ipairs(Config.Categories) do
        local it = pieces[c.key]
        local parts = it and (it.metadata or {}).gender == gender and it.metadata.parts or false
        state[src].worn[c.key] = signature(parts)
        all[c.key] = parts
    end
    TriggerClientEvent('d11_clothing:dress', src, all)
end)

local function inStore(src)
    return GetResourceState('d11_stores') == 'started' and exports.d11_stores:InStore(src)
end

-- WHIP's editor saves the look through this event (whip_core/server/events_misc.lua). We listen to the same name:
-- the client checks whether the clothes changed and, if so, sends what is worn.
RegisterNetEvent('whip_core:server:saveAppearance', function(appearance)
    local src = source
    -- At a d11_stores store the purchase comes as d11_stores:paid instead.
    if inStore(src) then return end
    if state[src] and type(appearance) == 'table' then TriggerClientEvent('d11_clothing:check', src, appearance) end
end)

-- A purchase paid at a d11_stores store: the client checks the new look and sends what is worn.
AddEventHandler('d11_stores:paid', function(src, appearance)
    if state[src] and type(appearance) == 'table' then TriggerClientEvent('d11_clothing:check', src, appearance) end
end)

RegisterNetEvent('d11_clothing:editor', function(gender, current)
    local src = source
    local e = state[src]
    if not e or not validGender(gender) or type(current) ~= 'table' then return end
    e.gender = gender
    reconcile(src, current)
end)

AddEventHandler('playerDropped', function() state[source], busy[source] = nil, nil end)
AddEventHandler('whip_core:player:logout', function(d)
    local src = type(d) == 'table' and d.source or source
    if src then state[src], busy[src] = nil, nil end
end)

-- ============================================
-- Items, slots and Use (put on / take off)
-- ============================================

local function use(src, slotData, addr)
    local cat = CAT_OF_ITEM[slotData.item]
    if not cat then return false end
    if addr and addr.sub == 'accessory' then
        local ok = exports.whip_core:StoreMove(addr, pockets(src), { reason = 'd11_clothing: take off' })
        if not ok then return false, L('It does not fit in your pockets', 'Não cabe nos bolsos') end
        return false
    end
    local e = state[src]
    if not e then return false, L('Wait for your character to load', 'Aguarde o personagem carregar') end
    if (slotData.metadata or {}).gender ~= e.gender then return false, L('That piece is for the other body', 'Essa peça é de outro corpo') end
    local target = strip(src, SLOT_OF[cat])
    if exports.whip_core:GetItemAt(target) then
        local ok = exports.whip_core:StoreMove(target, pockets(src), { reason = 'd11_clothing: swap' })
        if not ok then return false, L('The piece you are wearing does not fit in your pockets', 'Não cabe nos bolsos a peça que você está vestindo') end
    end
    local ok, why = exports.whip_core:StoreMove(addr, target, { reason = 'd11_clothing: put on' })
    if not ok then return false, why or L('Could not put it on', 'Não deu para vestir') end
    return false
end

Whip.register(function()
    for _, c in ipairs(Config.Categories) do
        local key = itemOf(c.key)
        local ok, why = Whip.core:RegisterItem(key, {
            name = c.label,
            desc = L('Clothing. Use to put it on or take it off; worn, it sits in Equipped.',
                     'Roupa. Use para vestir ou tirar; vestida, fica no Equipado.'),
            weight = Config.Weight, type = 'clothing', stack = false, usable = true,
            metaFields = {
                { key = 'piece', label = L('Piece', 'Peça') },
                { key = 'colour', label = L('Colour', 'Cor') },
                { key = 'body', label = L('Body', 'Corpo') },
            },
        })
        if not ok then print(('[d11_clothing] item %s refused: %s'):format(key, tostring(why))) end
        Whip.core:RegisterUseHandler(key, function(src, _, slotData, addr) return use(src, slotData, addr) end)
        local okSlot, whySlot = Whip.core:RegisterAccessorySlot({ slot = SLOT_OF[c.key], accepts = key, label = c.label })
        if not okSlot then print(('[d11_clothing] slot %d (%s) refused: %s'):format(SLOT_OF[c.key], c.label, tostring(whySlot))) end
    end
end)
