-- The store visit: the server decides what the editor unlocks and charges before the look is kept.
--   whip_core 1.2.0+   EditAppearance on the client, GetAppearanceChanges + ChargePlayer + SetPlayerAppearance here.
--   whip_core 1.0.1 / 1.1.x   the appearance-policy patch: SetAppearancePolicy(source, { allow, onQuote, onSave }).

local active = {}   -- [source] = { store = index, only = { categories }, prices = { [category] = $ } }

-- For other resources (d11_clothing): is this player at a store right now?
exports('InStore', function(src) return active[tonumber(src)] ~= nil end)

local REACH = 6.0

local function posOf(store)
    local p = store and store.pos
    if type(p) ~= 'vector3' and type(p) ~= 'table' then return nil end
    return vector3(tonumber(p.x) or 0.0, tonumber(p.y) or 0.0, tonumber(p.z) or 0.0)
end

local function near(src, store)
    local pos, ped = posOf(store), GetPlayerPed(src)
    return pos and ped ~= 0 and #(GetEntityCoords(ped) - pos) <= REACH
end

local function same(a, b) return json.encode(a) == json.encode(b) end

local function priceOf(t, group) return math.max(0, math.floor(tonumber(t['price_' .. group]) or 0)) end

--- The payment methods the settings page allows.
local function methods()
    local p = Config.Payment or 'auto'
    return { cash = p ~= 'bank', bank = p ~= 'cash' }
end

--- 'cash' | 'bank' | 'auto' for ChargePlayer, or nil and why.
local function pickMethod(asked)
    local m = methods()
    if asked ~= 'cash' and asked ~= 'bank' then asked = nil end
    if asked and not m[asked] then return nil, L('This store does not take that payment', 'Esta loja não aceita esse pagamento') end
    if asked then return asked end
    return (m.cash and m.bank) and 'auto' or (m.cash and 'cash' or 'bank')
end

--- Charges `total`; the receipt, or nil and why.
local function charge(src, t, total, asked)
    local method, why = pickMethod(asked)
    if not method then return nil, why end
    local receipt, err = exports.whip_core:ChargePlayer(src, total, { method = method, reason = t.name or 'Store' })
    if not receipt then return nil, err or L('Payment refused', 'Pagamento recusado') end
    exports.whip_core:NotifyPlayer(src, ('%s: $%d (%s)'):format(t.name or 'Store', total,
        receipt.method == 'bank' and L('bank', 'banco') or L('cash', 'dinheiro')), 'success')
    return receipt
end

--- Paid and kept: tell whoever listens (d11_clothing turns the new clothes into items), after whip_core saved.
local function paid(src, look)
    active[src] = nil
    SetTimeout(250, function() TriggerEvent('d11_stores:paid', src, look) end)
end

-- ============================================
-- Which way: whip_core 1.2.0's own store, or the patch
-- ============================================

local function versionAtLeast(have, want)
    local a, b = {}, {}
    for n in tostring(have):gmatch('%d+') do a[#a + 1] = tonumber(n) end
    for n in tostring(want):gmatch('%d+') do b[#b + 1] = tonumber(n) end
    for i = 1, math.max(#a, #b) do
        if (a[i] or 0) ~= (b[i] or 0) then return (a[i] or 0) > (b[i] or 0) end
    end
    return true
end

local function native()
    return versionAtLeast(GetResourceMetadata('whip_core', 'version', 0) or '0', '1.2.0')
end

-- ============================================
-- The cart with the patch: every changed item with its group's price
-- ============================================
-- Arms (3) and decal (10) are left out: they follow the top and are not a purchase.

local PIECES = {
    { '11', L('Top', 'Blusa') }, { '8', L('Undershirt', 'Camiseta') }, { '4', L('Pants', 'Calça') },
    { '6', L('Shoes', 'Calçado') }, { '1', L('Mask', 'Máscara') }, { '7', L('Accessory', 'Acessório') },
    { '9', L('Vest', 'Colete') }, { '5', L('Bag', 'Bolsa') },
}
local PROPS = {
    { '0', L('Hat', 'Chapéu') }, { '1', L('Glasses', 'Óculos') }, { '2', L('Earring', 'Brinco') },
    { '6', L('Watch', 'Relógio') }, { '7', L('Bracelet', 'Pulseira') },
}
local OVERLAYS = {
    hair = { { 'eyebrows', L('Eyebrows', 'Sobrancelha') } },
    beard = { { 'beard', L('Beard', 'Barba') }, { 'chestHair', L('Chest hair', 'Pelos do peito') } },
    makeup = { { 'makeup', L('Makeup', 'Maquiagem') }, { 'blush', L('Blush', 'Blush') }, { 'lipstick', L('Lipstick', 'Batom') } },
}
local SKIN = { 'blemishes', 'ageing', 'complexion', 'sunDamage', 'moles' }

local function changedPart(old, new, group, key)
    return not same((old[group] or {})[key], (new[group] or {})[key])
end

local function detail(v)
    if type(v) ~= 'table' then return '' end
    if (tonumber(v.drawable) or 0) < 0 then return L(' (off)', ' (tirar)') end
    return L(' #%d, colour %d', ' nº %d, cor %d'):format(tonumber(v.drawable) or 0, tonumber(v.texture) or 0)
end

--- { label, price, key } for what changed between the saved look and the new one, in the groups the store unlocks.
local function cartOf(t, old, new)
    local lines = {}
    if not old then return lines end
    local function add(g, label, key)
        if t[g] then lines[#lines + 1] = { label = label, price = priceOf(t, g), key = key } end
    end

    for _, p in ipairs(PIECES) do
        if changedPart(old, new, 'components', p[1]) then add('clothes', p[2] .. detail((new.components or {})[p[1]]), 'c:' .. p[1]) end
    end
    for _, p in ipairs(PROPS) do
        if changedPart(old, new, 'props', p[1]) then add('accessories', p[2] .. detail((new.props or {})[p[1]]), 'p:' .. p[1]) end
    end
    if not same(old.hair, new.hair) or not same(old.hairFade, new.hairFade) then add('hair', L('Hair', 'Cabelo'), 'hair') end
    for g, list in pairs(OVERLAYS) do
        for _, o in ipairs(list) do if changedPart(old, new, 'overlays', o[1]) then add(g, o[2], 'ov:' .. o[1]) end end
    end
    local had = {}
    for _, tt in ipairs(old.tattoos or {}) do had[(tt.collection or '') .. '/' .. (tt.overlay or '')] = true end
    for _, tt in ipairs(new.tattoos or {}) do
        local k = (tt.collection or '') .. '/' .. (tt.overlay or '')
        if not had[k] then add('tattoos', L('New tattoo', 'Tatuagem nova'), 'tat:' .. k) end
    end
    local face = not same(old.headBlend, new.headBlend) or not same(old.faceFeatures, new.faceFeatures)
        or old.eyeColor ~= new.eyeColor
    for _, k in ipairs(SKIN) do face = face or changedPart(old, new, 'overlays', k) end
    if face then add('face', L('Face and skin', 'Rosto e pele'), 'face') end
    return lines
end

local function totalOf(lines)
    local n = 0
    for _, l in ipairs(lines) do n = n + l.price end
    return n
end

local function openWithPatch(src, store, t, only)
    local ok, why = exports.whip_core:SetAppearancePolicy(src, {
        allow = only,
        -- The cart the editor shows before buying: lines, total and what the player has in each method.
        onQuote = function(who, old, new)
            local lines, m = cartOf(t, old, new), methods()
            return {
                title = store.name or t.name,
                lines = lines,
                total = totalOf(lines),
                cash = m.cash and (tonumber(exports.whip_core:GetPlayerCash(who)) or 0) or false,
                bank = m.bank and (tonumber(exports.whip_core:GetBalance(who)) or false) or false,
            }
        end,
        onSave = function(who, old, new, opts)
            local total = totalOf(cartOf(t, old, new))
            if total > 0 then
                local receipt, err = charge(who, t, total, type(opts) == 'table' and opts.method or nil)
                if not receipt then return false, err end
            end
            paid(who, new)
            return true
        end,
    })
    return ok, why
end

-- ============================================
-- whip_core 1.2.0+: the editor's own checkout, the purchase checked and kept here
-- ============================================

Whip.register(function()
    if not native() then return end
    Whip.core:SecureCallback('d11_stores:buy', {
        rateLimit = 1500,
        params = { { 'look', 'any' }, { 'method', 'enum', { 'cash', 'bank' }, 'cash' } },
    }, function(src, _, look, method)
        local visit = active[src]
        local store = visit and (Config.Stores or {})[visit.store]
        local t = store and Config.Types[store.type]
        if not t then return false, L('The store visit is over', 'O atendimento acabou') end
        if not near(src, store) then return false, L('You walked away from the counter', 'Você saiu do balcão') end
        local changes, why = exports.whip_core:GetAppearanceChanges(src, look, visit.only)
        if not changes then return false, why end
        local total = 0
        for id, n in pairs(changes) do total = total + (visit.prices[id] or 0) * n end
        local receipt
        if total > 0 then
            receipt, why = charge(src, t, total, method)
            if not receipt then return false, why end
        end
        local ok, kept = exports.whip_core:SetPlayerAppearance(src, look, { only = visit.only })
        if not ok then
            if receipt then exports.whip_core:RefundPlayer(receipt) end
            return false, kept
        end
        paid(src, kept)
        return true
    end)
end)

-- ============================================
-- The visit
-- ============================================

RegisterNetEvent('d11_stores:open', function(i)
    local src = source
    local store = type(i) == 'number' and (Config.Stores or {})[i]
    local t = store and Config.Types[store.type]
    if not t or not near(src, store) then return end

    local only, prices, shown = {}, {}, {}
    for _, g in ipairs(Config.Groups) do
        if t[g.key] then
            local p = priceOf(t, g.key)
            for _, cat in ipairs(g.cats) do
                only[#only + 1] = cat
                prices[cat] = Config.FreeCats[cat] and 0 or p
            end
            if p > 0 then shown[#shown + 1] = ('%s $%d'):format(g.label, p) end
        end
    end
    if #only == 0 then
        return exports.whip_core:NotifyPlayer(src, L('This store is closed.', 'Esta loja está fechada.'), 'error')
    end

    local opts = {
        only = only,
        title = store.name or t.name,
        sub = #shown > 0 and (L('Per item: ', 'Por item: ') .. table.concat(shown, ' · ')) or L('Free', 'Sem custo'),
    }
    if native() then
        local m = methods()
        opts.mode, opts.prices, opts.methods = 'native', prices, {}
        if m.cash then opts.methods[#opts.methods + 1] = 'cash' end
        if m.bank then opts.methods[#opts.methods + 1] = 'bank' end
        opts.wallet = { cash = tonumber(exports.whip_core:GetPlayerCash(src)) or nil,
                        bank = tonumber(exports.whip_core:GetBalance(src)) or nil }
    else
        local ran, ok, why = pcall(openWithPatch, src, store, t, only)
        if not ran or not ok then
            print(('[d11_stores] whip_core %s has no store support: apply whip_core-patches/whip_core-appearance-policy-*.patch or update to 1.2.0 (%s)')
                :format(GetResourceMetadata('whip_core', 'version', 0) or '?', tostring(ran and why or ok)))
            return exports.whip_core:NotifyPlayer(src, L('This store is not available.', 'Atendimento indisponível.'), 'error')
        end
        opts.mode, opts.texts = 'patch', Config.CartText
    end
    active[src] = { store = i, only = only, prices = prices }
    TriggerClientEvent('d11_stores:opened', src, opts)
end)

RegisterNetEvent('d11_stores:closed', function()
    local src = source
    if active[src] then
        active[src] = nil
        if not native() then pcall(function() exports.whip_core:SetAppearancePolicy(src, nil) end) end
    end
end)

AddEventHandler('playerDropped', function() active[source] = nil end)
