-- The settings page: /whip -> Settings -> Clothing stores (Whip.configPage; permanent admins only).
-- config.lua holds the defaults; what an admin saves wins, is written into Config on both sides and applies at once.

local function typePage(kind)
    local base = 'Types.' .. kind .. '.'
    local s = {
        { key = base .. 'name', type = 'string', maxLen = 40, label = L('Name (blip and prompt)', 'Nome (blip e prompt)') },
    }
    for _, g in ipairs(Config.Groups) do
        s[#s + 1] = { key = base .. g.key, type = 'bool', label = L('Unlocks: ', 'Libera: ') .. g.label }
        s[#s + 1] = { key = base .. 'price_' .. g.key, type = 'int', min = 0, max = 100000, unit = '$',
            label = L('Price: ', 'Preço: ') .. g.label, shownWhen = { path = base .. g.key, equals = true },
            help = g.key == 'face'
                and L('With the whip_core patch: charged once if anything on the face changed. On whip_core 1.2.0: per changed part.',
                      'Com o patch do whip_core: cobrado uma vez se qualquer coisa do rosto mudar. No whip_core 1.2.0: por parte alterada.')
                or L('Per changed item (each piece, each new tattoo). 0 = free.',
                     'Por item trocado (cada peça, cada tatuagem nova). 0 = de graça.') }
    end
    s[#s + 1] = { key = base .. 'blip', type = 'int', min = 1, max = 900, label = L('Blip icon (sprite)', 'Ícone do blip (sprite)') }
    s[#s + 1] = { key = base .. 'colour', type = 'int', min = 0, max = 85, label = L('Blip colour', 'Cor do blip') }
    s[#s + 1] = { key = base .. 'clerk', type = 'string', maxLen = 40, pattern = '^[%w_]+$',
        patternWhy = L('a ped model name (letters, digits and _)', 'nome de modelo de ped (letras, números e _)'),
        label = L('Clerk model', 'Modelo do atendente') }
    return s
end

local groups = {}
for _, t in ipairs(Config.TypeOptions) do
    groups[#groups + 1] = { label = t.label, settings = typePage(t.value) }
end
groups[#groups + 1] = { label = L('Locations', 'Lugares'), settings = {
    { key = 'Stores', type = 'records', maxItems = 120, widget = 'mapPoints',
      marker = { sprite = 73, colour = 47, name = Config.Types.clothing.name },
      fields = {
          { key = 'pos', type = 'vec3', here = true, label = L('Where the clerk stands', 'Onde o atendente fica'),
            limits = { x = { -4000, 8000 }, y = { -7000, 8000 }, z = { -200, 2000 } } },
          { key = 'name', type = 'string', maxLen = 50, label = L('Name', 'Nome') },
          { key = 'type', type = 'enum', options = Config.TypeOptions, label = L('Type', 'Tipo') },
          { key = 'heading', type = 'number', min = 0, max = 360, step = 5,
            label = L('Where the clerk faces (degrees)', 'Para onde o atendente olha (graus)') },
      },
      label = L('Stores on the map', 'Lojas no mapa'),
      help = L('One row per store. On the map: drag to move, click to rename or remove, or add one where you stand.',
               'Uma linha por loja. No mapa: arraste para mover, clique para renomear ou remover, ou adicione onde você está.') },
} }
groups[#groups + 1] = { label = L('Payment', 'Pagamento'), settings = {
    { key = 'Payment', type = 'enum', label = L('How it charges', 'Como cobra'), options = {
        { value = 'auto', label = L('Cash or bank, the player picks', 'Dinheiro ou banco, o jogador escolhe') },
        { value = 'cash', label = L('Cash only', 'Só dinheiro na mão') },
        { value = 'bank', label = L('Bank only', 'Só banco') },
    } },
} }

Whip.configPage({ label = L('Clothing stores', 'Lojas de roupa'), groups = groups })
