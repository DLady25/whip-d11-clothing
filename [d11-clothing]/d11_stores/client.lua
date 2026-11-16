-- Stores (clothing, barber, tattoo, surgeon): blip, clerk and the prompt that opens WHIP's editor on what the
-- store type unlocks. Everything comes from Config.Stores / Config.Types, which the settings page changes in game.

local blips, peds, actions = {}, {}, {}

local function typeOf(store) return Config.Types[store.type] end

--- The position as a vector3 (the settings page may hand back a { x, y, z } table).
local function posOf(store)
    local p = store.pos
    if type(p) ~= 'vector3' and type(p) ~= 'table' then return nil end
    return vector3(tonumber(p.x) or 0.0, tonumber(p.y) or 0.0, tonumber(p.z) or 0.0)
end

local function clear()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    for _, p in pairs(peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    for _, id in ipairs(actions) do pcall(function() exports.whip_core:RemoveAction(id) end) end
    blips, peds, actions = {}, {}, {}
end

local function spawnClerk(i, store)
    local t = typeOf(store)
    local model = joaat(t and t.clerk or 's_f_y_shop_mid')
    if not IsModelInCdimage(model) then return end
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(model) or peds[i] then return end
    local pos = posOf(store)
    if not pos then return end
    local ped = CreatePed(4, model, pos.x, pos.y, pos.z - 1.0, tonumber(store.heading) or 0.0, false, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    SetTimeout(1500, function() if DoesEntityExist(ped) then FreezeEntityPosition(ped, true) end end)
    peds[i] = ped
end

-- ============================================
-- Opening the editor (the server checks the distance and builds what is unlocked and the prices)
-- ============================================

local function serve(i)
    if IsPedInAnyVehicle(PlayerPedId(), true) then
        return exports.whip_core:Notify(L('Get out of the vehicle first', 'Saia do veículo primeiro'), 'error')
    end
    TriggerServerEvent('d11_stores:open', i)
end

local function failed(why)
    exports.whip_core:Notify(why or L('The store could not open', 'Não deu para abrir o atendimento'), 'error')
    TriggerServerEvent('d11_stores:closed')
end

RegisterNetEvent('d11_stores:opened', function(opts)
    if type(opts) ~= 'table' then return end
    CreateThread(function()
        if opts.mode == 'native' then
            -- whip_core 1.2.0+: its own store editor and checkout. Save comes back here, the server charges.
            local ok, why = exports.whip_core:EditAppearance({
                only = opts.only, prices = opts.prices, methods = opts.methods, wallet = opts.wallet,
                title = opts.title, sub = opts.sub,
                onSave = function(look, method)
                    return Whip.core:Callback('d11_stores:buy', look, method)
                end,
                onClose = function() TriggerServerEvent('d11_stores:closed') end,
            })
            if not ok then failed(why) end
            return
        end
        -- whip_core 1.0.1 / 1.1.x with the appearance-policy patch: the cart on the right, the server checks and charges.
        local ok, why = exports.whip_core:OpenCharacterEditor({
            allow = opts.only, title = opts.title, sub = opts.sub, policy = true, texts = opts.texts,
        })
        if not ok then return failed(why) end
        -- The editor holds NUI focus while open: when it lets go, the visit is over (saved or not).
        Wait(1000)
        while IsNuiFocused() do Wait(500) end
        TriggerServerEvent('d11_stores:closed')
    end)
end)

-- ============================================
-- Building (at start, and again when the settings page changes the stores or the types)
-- ============================================

local function build()
    clear()
    for i, store in ipairs(Config.Stores or {}) do
        local t, pos = typeOf(store), posOf(store)
        if t and pos then
            local b = AddBlipForCoord(pos.x, pos.y, pos.z)
            SetBlipSprite(b, tonumber(t.blip) or 73)
            SetBlipColour(b, tonumber(t.colour) or 0)
            SetBlipScale(b, 0.7)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(t.name or L('Store', 'Loja'))
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b

            local id = 'd11_store_' .. i
            exports.whip_core:AddAction({
                id = id,
                at = { coords = pos },
                label = t.name or L('Store', 'Loja'), icon = 'store',
                focusMode = 'near',
                options = { { id = 'open', label = L('Shop', 'Atendimento'), icon = 'store', onSelect = function() serve(i) end } },
            })
            actions[#actions + 1] = id
        end
    end
end

local ready = false
Whip.register(function() ready = true build() end)
Whip.onConfigChanged('Stores', function() if ready then build() end end)
Whip.onConfigChanged('Types', function() if ready then build() end end)

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, store in ipairs(Config.Stores or {}) do
            local at = posOf(store)
            if at then
                local d = #(pos - at)
                if d < 60.0 and not peds[i] then spawnClerk(i, store)
                elseif d > 80.0 and peds[i] then
                    if DoesEntityExist(peds[i]) then DeleteEntity(peds[i]) end
                    peds[i] = nil
                end
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clear() end
end)
