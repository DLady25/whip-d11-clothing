Config = {}

-- Language: setr d11_locale en | pt-BR in server.cfg (default en). L(english, portuguese).
local PT = GetConvar('d11_locale', 'en') == 'pt-BR'
function L(en, pt) return PT and pt or en end

-- These are the defaults. What an admin saves on the settings page (/whip -> Settings -> Clothing stores) wins
-- and applies right away.

-- The editor groups a store type can unlock, and the editor categories in each
-- (whip_core/html/js/creator-data.js; 'tattoos' = every tattoo zone).
Config.Groups = {
    { key = 'clothes',     label = L('Clothes', 'Roupas'),                   cats = { 'mask', 'tops', 'undershirt', 'arms', 'legs', 'shoes', 'accessory', 'armor', 'decal', 'bag' } },
    { key = 'accessories', label = L('Accessories', 'Acessórios'),           cats = { 'hat', 'glasses', 'ear', 'watch', 'bracelet' } },
    { key = 'outfits',     label = L('Saved looks', 'Visuais salvos'),       cats = { 'outfits' } },
    { key = 'hair',        label = L('Hair and eyebrows', 'Cabelo e sobrancelha'), cats = { 'hair', 'eyebrows' } },
    { key = 'beard',       label = L('Beard and body hair', 'Barba e pelos'), cats = { 'beard', 'chestHair' } },
    { key = 'makeup',      label = L('Makeup', 'Maquiagem'),                 cats = { 'makeup' } },
    { key = 'tattoos',     label = L('Tattoos', 'Tatuagens'),                cats = { 'tattoos' } },
    { key = 'face',        label = L('Face and skin', 'Rosto e pele'),       cats = { 'heritage', 'features', 'eyes', 'skin' } },
}

-- Arms and decal follow the top: never charged.
Config.FreeCats = { arms = true, decal = true }

-- Seconds between pressing the prompt and the editor opening: a notice tells the player to stand where the camera will
-- see them (in the open, facing the room). 0 opens at once.
Config.OpenDelay = 3

-- Store types: what each one unlocks (<group> = true) and the price per changed item (price_<group>, $; 0 = free).
-- With the patch, "Face and skin" is charged once whatever changed; on whip_core 1.2.0 it is per changed part.
-- Blip, blip colour and clerk ped per type.
Config.Types = {
    clothing = {
        name = L('Clothing store', 'Loja de roupas'), blip = 73, colour = 47, clerk = 's_f_y_shop_mid',
        clothes = true, accessories = true, outfits = true, hair = false, beard = false, makeup = false, tattoos = false, face = false,
        price_clothes = 120, price_accessories = 60, price_outfits = 0, price_hair = 0, price_beard = 0, price_makeup = 0, price_tattoos = 0, price_face = 0,
    },
    barber = {
        name = L('Barber', 'Barbearia'), blip = 71, colour = 0, clerk = 's_f_m_fembarber',
        clothes = false, accessories = false, outfits = false, hair = true, beard = true, makeup = true, tattoos = false, face = false,
        price_clothes = 0, price_accessories = 0, price_outfits = 0, price_hair = 80, price_beard = 40, price_makeup = 40, price_tattoos = 0, price_face = 0,
    },
    tattoo = {
        name = L('Tattoo studio', 'Estúdio de tatuagem'), blip = 75, colour = 1, clerk = 'u_m_y_tattoo_01',
        clothes = false, accessories = false, outfits = false, hair = false, beard = false, makeup = false, tattoos = true, face = false,
        price_clothes = 0, price_accessories = 0, price_outfits = 0, price_hair = 0, price_beard = 0, price_makeup = 0, price_tattoos = 250, price_face = 0,
    },
    surgeon = {
        name = L('Plastic surgeon', 'Cirurgião plástico'), blip = 102, colour = 0, clerk = 's_m_m_doctor_01',
        clothes = false, accessories = false, outfits = false, hair = false, beard = false, makeup = false, tattoos = false, face = true,
        price_clothes = 0, price_accessories = 0, price_outfits = 0, price_hair = 0, price_beard = 0, price_makeup = 0, price_tattoos = 0, price_face = 5000,
    },
}

Config.TypeOptions = {
    { value = 'clothing', label = Config.Types.clothing.name }, { value = 'barber', label = Config.Types.barber.name },
    { value = 'tattoo', label = Config.Types.tattoo.name }, { value = 'surgeon', label = Config.Types.surgeon.name },
}

-- Where each store is: the clerk (pos at body height, heading = where they face). GTA's own clothing stores,
-- barbers and tattoo studios; the surgeon has none by default (add them on the settings page).
local barber, tattoo = L('Barber', 'Barbearia'), L('Tattoo', 'Tatuagem')
Config.Stores = {
    { name = 'Discount Store (Strawberry)',   type = 'clothing', pos = vector3(73.8728, -1392.0785, 29.3761),   heading = 278.8 },
    { name = 'Ponsonbys (Rockford Hills)',    type = 'clothing', pos = vector3(-709.1233, -151.4137, 37.4151),  heading = 120.2 },
    { name = 'Suburban (Del Perro)',          type = 'clothing', pos = vector3(-1193.8881, -766.9583, 17.3163), heading = 212.0 },
    { name = 'Binco (Textile City)',          type = 'clothing', pos = vector3(426.9803, -807.0754, 29.4911),   heading = 85.2 },
    { name = 'Ponsonbys (Burton)',            type = 'clothing', pos = vector3(-165.0957, -303.4923, 39.7333),  heading = 252.7 },
    { name = 'Binco (Vespucci)',              type = 'clothing', pos = vector3(-822.4478, -1071.9479, 11.3281), heading = 211.2 },
    { name = 'Ponsonbys (Morningwood)',       type = 'clothing', pos = vector3(-1448.6345, -237.6724, 49.8133), heading = 47.8 },
    { name = 'Discount Store (Paleto Bay)',   type = 'clothing', pos = vector3(5.2391, 6510.8462, 31.8778),     heading = 39.3 },
    { name = 'Suburban (Harmony)',            type = 'clothing', pos = vector3(612.9161, 2762.7390, 42.0881),   heading = 272.1 },
    { name = 'Discount Store (Grand Senora)', type = 'clothing', pos = vector3(1197.4762, 2711.7039, 38.2226),  heading = 174.9 },
    { name = 'Suburban (Chumash)',            type = 'clothing', pos = vector3(-3169.4568, 1043.2114, 20.8632), heading = 63.3 },
    { name = 'Discount Store (Route 68)',     type = 'clothing', pos = vector3(-1101.8413, 2712.1074, 19.1078), heading = 220.8 },
    { name = barber .. ' (Rockford Hills)',   type = 'barber',   pos = vector3(-821.8442, -183.3238, 37.5689),  heading = 207.5 },
    { name = barber .. ' (Davis)',            type = 'barber',   pos = vector3(134.3835, -1707.8057, 29.2916),  heading = 143.6 },
    { name = barber .. ' (Vespucci)',         type = 'barber',   pos = vector3(-1284.2587, -1115.1111, 6.9901), heading = 91.2 },
    { name = barber .. ' (Sandy Shores)',     type = 'barber',   pos = vector3(1930.5654, 3728.0281, 32.8444),  heading = 211.1 },
    { name = barber .. ' (Mirror Park)',      type = 'barber',   pos = vector3(1211.4739, -470.7102, 66.2080),  heading = 75.5 },
    { name = barber .. ' (Hawick)',           type = 'barber',   pos = vector3(-30.6521, -151.7624, 57.0765),   heading = 340.8 },
    { name = barber .. ' (Paleto Bay)',       type = 'barber',   pos = vector3(-277.7421, 6230.6191, 31.6955),  heading = 45.2 },
    { name = tattoo .. ' (Paleto Bay)',       type = 'tattoo',   pos = vector3(-291.9040, 6199.8682, 31.4871),  heading = 231.0 },
    { name = tattoo .. ' (El Burro Heights)', type = 'tattoo',   pos = vector3(1324.8844, -1650.6941, 52.2752), heading = 128.9 },
    { name = tattoo .. ' (Vespucci)',         type = 'tattoo',   pos = vector3(-1151.7233, -1424.5104, 4.9545), heading = 120.5 },
    { name = tattoo .. ' (Vinewood)',         type = 'tattoo',   pos = vector3(320.0719, 181.5661, 103.5865),   heading = 247.5 },
    { name = tattoo .. ' (Chumash)',          type = 'tattoo',   pos = vector3(-3171.1780, 1073.3529, 20.8292), heading = 334.3 },
    { name = tattoo .. ' (Sandy Shores)',     type = 'tattoo',   pos = vector3(1862.4734, 3748.4172, 33.0318),  heading = 28.6 },
}

Config.Payment = 'auto'   -- 'cash', 'bank' or 'auto' (the player picks; cash first when it covers the total)

-- The cart's words with the patch (whip_core/html/js/creator.js CART_TEXT). English is built in.
Config.CartText = PT and {
    cart = 'Carrinho', free = 'Grátis', remove = 'Tirar do carrinho', empty = 'Nada trocado ainda. Escolha à esquerda.',
    total = 'Total', cash = 'Dinheiro', bank = 'Banco', buy = 'Confirmar compra', paying = 'Pagando…', save = 'Salvar',
    short = 'Saldo insuficiente para este total.', failed = 'Não deu para concluir a compra', locale = 'pt-BR',
} or nil
