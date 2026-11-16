Config = {}

-- Language: setr d11_locale en | pt-BR in server.cfg (default en). L(english, portuguese).
local PT = GetConvar('d11_locale', 'en') == 'pt-BR'
function L(en, pt) return PT and pt or en end

-- What is worn is the inventory's "Equipped" strip: slot FirstSlot + n - 1 is category n below.
-- Needs Config.ContainerSlots.accessory = 16 in whip_core/config.lua (WHIP's 5 + these 11).
Config.FirstSlot = 6

-- A category may carry more than one part: the shirt carries the top, the undershirt, the arms and the decal,
-- or the body is left without arms or clipping through. c = component, p = prop. Bag (5) and gloves (they share
-- 3 with the arms) are left out.
Config.Categories = {
    { key = 'shirt',    label = L('Shirt', 'Camisa'),                 c = { 11, 8, 3, 10 } },
    { key = 'pants',    label = L('Pants', 'Calça'),                  c = { 4 } },
    { key = 'shoes',    label = L('Shoes', 'Sapatos'),                c = { 6 } },
    { key = 'mask',     label = L('Mask', 'Máscara'),                 c = { 1 } },
    { key = 'neck',     label = L('Neck', 'Acessório de pescoço'),    c = { 7 } },
    { key = 'vest',     label = L('Vest', 'Colete'),                  c = { 9 } },
    { key = 'hat',      label = L('Hat', 'Chapéu'),                   p = { 0 } },
    { key = 'glasses',  label = L('Glasses', 'Óculos'),               p = { 1 } },
    { key = 'ears',     label = L('Ears', 'Orelha'),                  p = { 2 } },
    { key = 'watch',    label = L('Watch', 'Relógio'),                p = { 6 } },
    { key = 'bracelet', label = L('Bracelet', 'Pulseira'),            p = { 7 } },
}

-- The body without the piece: the same "undressed" as WHIP's editor (whip_core/client/appearance.lua UNDRESSED),
-- by collection and number inside it. A prop without a piece is none (-1).
Config.Undressed = {
    male = {
        [1] = { 'base', 0 }, [3] = { 'base', 15 }, [4] = { 'base', 14 }, [6] = { 'male_apt01', 1 },
        [7] = { 'base', 0 }, [8] = { 'base', 15 }, [9] = { 'base', 0 }, [10] = { 'base', 0 }, [11] = { 'base', 15 },
    },
    female = {
        [1] = { 'base', 0 }, [3] = { 'base', 15 }, [4] = { 'base', 15 }, [6] = { 'female_apt01', 1 },
        [7] = { 'base', 0 }, [8] = { 'base', 14 }, [9] = { 'base', 0 }, [10] = { 'base', 0 }, [11] = { 'base', 15 },
    },
}

-- kg per piece. 0: worn clothes are not load. The strip only holds 10 kg (Config.MaxWeight.accessory) and the
-- phone, wallet and cash already fill it: with a weight, a piece was refused ("Too heavy") in the Equipped strip.
Config.Weight = 0.0
