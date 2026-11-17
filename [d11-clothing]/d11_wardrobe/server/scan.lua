-- Keeps a /roupascan result as data/scan-<body>.json. Only for players with the 'command' ace (admins).
local RES = GetCurrentResourceName()
local MAX = 20 * 1024 * 1024

RegisterNetEvent('d11_wardrobe:scan', function(body, payload)
    local src = source
    if not IsPlayerAceAllowed(src, 'command') then
        TriggerClientEvent('d11_wardrobe:scanSaved', src, body, nil, false, 'sem permissão (ace command)')
        return
    end
    if body ~= 'male' and body ~= 'female' then return end
    if type(payload) ~= 'string' or #payload > MAX then
        TriggerClientEvent('d11_wardrobe:scanSaved', src, body, nil, false, 'resultado grande demais')
        return
    end
    local ok = pcall(json.decode, payload)
    if not ok then
        TriggerClientEvent('d11_wardrobe:scanSaved', src, body, nil, false, 'resultado ilegível')
        return
    end
    local path = ('data/scan-%s.json'):format(body)
    local saved = SaveResourceFile(RES, path, payload, -1)
    print(('[d11_wardrobe] scan %s de %s: %s (%d KB)'):format(body, GetPlayerName(src) or src,
        saved and 'salvo' or 'FALHOU', math.floor(#payload / 1024)))
    TriggerClientEvent('d11_wardrobe:scanSaved', src, body, RES .. '/' .. path, saved, 'SaveResourceFile falhou')
end)
