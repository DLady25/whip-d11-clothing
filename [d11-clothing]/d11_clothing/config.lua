Config = {}

-- Language: setr d11_locale en | pt-BR in server.cfg (default en). L(english, portuguese).
local PT = GetConvar('d11_locale', 'en') == 'pt-BR'
function L(en, pt) return PT and pt or en end

-- What is worn is the inventory's "Equipped" strip: slot FirstSlot + n - 1 is category n below.
-- Needs Config.ContainerSlots.accessory = 16 in whip_core/config.lua (WHIP's 5 + these 11).
Config.FirstSlot = 6

-- A category may carry more than one part: the shirt carries the top, the undershirt, the arms and the decal,
-- or the body is left without arms or clipping through. c = component, p = prop.
-- Gloves: GTA has no glove slot, a glove is an arm (component 3) with the hand covered. The Shirt keeps the bare arm
-- of its type and the Gloves item the glove, worn on the shirt's arm type (data/gloves-<body>.json, base game).
-- Earrings, bracelet and decal (printed on the Shirt) stay on the body only, with no item.
Config.Categories = {
    { key = 'shirt',    label = L('Shirt', 'Camisa'),                 c = { 11, 8, 3, 10 } },
    { key = 'pants',    label = L('Pants', 'Calça'),                  c = { 4 } },
    { key = 'shoes',    label = L('Shoes', 'Sapatos'),                c = { 6 } },
    { key = 'mask',     label = L('Mask', 'Máscara'),                 c = { 1 } },
    { key = 'neck',     label = L('Neck', 'Acessório de pescoço'),    c = { 7 } },
    { key = 'vest',     label = L('Vest', 'Colete'),                  c = { 9 } },
    { key = 'hat',      label = L('Hat', 'Chapéu'),                   p = { 0 } },
    { key = 'glasses',  label = L('Glasses', 'Óculos'),               p = { 1 } },
    { key = 'gloves',   label = L('Gloves', 'Luvas'),                 c = { 3 }, gloves = true },
    { key = 'watch',    label = L('Watch', 'Relógio'),                p = { 6 } },
    { key = 'bag',      label = L('Bag', 'Bolsa'),                    c = { 5 } },
}

-- Categories of 1.0 that left (their items still exist and can be kept, but are no longer worn from the
-- inventory): at login, an old piece in a slot that changed owner goes to the pockets.
Config.Retired = {
    { key = 'ears',     label = L('Ears (old)', 'Orelha (antiga)') },
    { key = 'bracelet', label = L('Bracelet (old)', 'Pulseira (antiga)') },
}

-- The body without the piece: the same "undressed" as WHIP's editor (whip_core/client/appearance.lua UNDRESSED),
-- by collection and number inside it. A prop without a piece is none (-1).
Config.Undressed = {
    male = {
        [1] = { 'base', 0 }, [3] = { 'base', 15 }, [4] = { 'base', 14 }, [5] = { 'base', 0 }, [6] = { 'male_apt01', 1 },
        [7] = { 'base', 0 }, [8] = { 'base', 15 }, [9] = { 'base', 0 }, [10] = { 'base', 0 }, [11] = { 'base', 15 },
    },
    female = {
        [1] = { 'base', 0 }, [3] = { 'base', 15 }, [4] = { 'base', 15 }, [5] = { 'base', 0 }, [6] = { 'female_apt01', 1 },
        [7] = { 'base', 0 }, [8] = { 'base', 14 }, [9] = { 'base', 0 }, [10] = { 'base', 0 }, [11] = { 'base', 15 },
    },
}

-- kg per piece. 0: worn clothes are not load. The strip only holds 10 kg (Config.MaxWeight.accessory) and the
-- phone, wallet and cash already fill it: with a weight, a piece was refused ("Too heavy") in the Equipped strip.
Config.Weight = 0.0
