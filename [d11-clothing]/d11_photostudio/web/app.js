// Estúdio de fotos do visual (d11_photostudio). Fala com este resource (poses, foto, salvar) e com a câmera do
// criador do whip_core (pelo Lua daqui, export CreatorCamera), que continua aberto por baixo.
const RES = 'd11_photostudio';
const post = (res, name, data) => fetch(`https://${res}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}),
}).then(r => r.json()).catch(() => ({}));
const me = (name, data) => post(RES, name, data);
// A câmera do criador: pelo Lua deste resource (export CreatorCamera do whip_core).
const cam = (data) => me('camera', data);
const $ = (id) => document.getElementById(id);

// Texts: English, or pt-BR with setr d11_locale pt-BR (client.lua sends it on open).
const TEXTS = {
    en: {
        frame: 'Photo', title: 'Photo studio', sub: 'Pick a pose for the photo of', look: 'your outfit', search: 'Search pose...',
        shoot: 'Take photo', back: 'Back to the outfit', controls: 'Controls', mouseKeys: 'Mouse and keyboard',
        drag: 'Drag', dragWhat: 'Camera: turn and raise', rdrag: 'Right-drag', turnPed: 'Turn the character',
        hold: 'Hold to turn', scroll: 'Scroll', zoom: 'Zoom in and out', front: 'Face the camera again',
        theShot: 'The outfit photo', again: 'Take another', use: 'Use this photo', busy: 'Taking the photo…',
        noPose: 'No pose (standing)', noMatch: 'No pose by that name.', failed: 'Could not take the photo',
    },
    'pt-BR': {
        frame: 'Foto', title: 'Estúdio de fotos', sub: 'Escolha a pose da foto de', look: 'seu visual', search: 'Buscar pose...',
        shoot: 'Tirar foto', back: 'Voltar ao visual', controls: 'Controles', mouseKeys: 'Mouse e teclado',
        drag: 'Arrastar', dragWhat: 'Câmera: girar e subir', rdrag: 'Arrastar (dir.)', turnPed: 'Girar o personagem',
        hold: 'Segure para girar', scroll: 'Rolar', zoom: 'Aproximar e afastar', front: 'De frente de novo',
        theShot: 'A foto do visual', again: 'Tirar outra', use: 'Usar esta foto', busy: 'Fotografando…',
        noPose: 'Sem pose (parado)', noMatch: 'Nenhuma pose com esse nome.', failed: 'Não deu para tirar a foto',
    },
};
let T = TEXTS.en;
function applyTexts(lang) {
    T = TEXTS[lang] || TEXTS.en;
    document.documentElement.lang = lang === 'pt-BR' ? 'pt-BR' : 'en';
    document.querySelectorAll('[data-t]').forEach((el) => { if (T[el.dataset.t]) el.textContent = T[el.dataset.t]; });
    document.querySelectorAll('[data-tp]').forEach((el) => { if (T[el.dataset.tp]) el.placeholder = T[el.dataset.tp]; });
}

let categories = [];
let tab = 0;
let pose = '';
let photo = null;
let open = false;

const fold = (t) => String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const esc = (t) => String(t).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function renderTabs() {
    $('tabs').innerHTML = categories.map((c, i) =>
        `<button class="tab${i === tab ? ' on' : ''}" data-tab="${i}">${esc(c.label)}</button>`).join('');
}

function renderPoses() {
    const words = fold($('search').value).split(/\s+/).filter(Boolean);
    const list = (categories[tab] || { poses: [] }).poses.filter(p => words.every(w => fold(p.label + ' ' + p.cmd).includes(w)));
    $('poses').innerHTML = `<button class="pose none${pose === '' ? ' on' : ''}" data-cmd="">${esc(T.noPose)}</button>`
        + list.map(p => `<button class="pose${p.cmd === pose ? ' on' : ''}" data-cmd="${esc(p.cmd)}">${esc(p.label)}</button>`).join('')
        + (list.length ? '' : `<div class="empty">${esc(T.noMatch)}</div>`);
}

function setPose(cmd) {
    pose = cmd;
    renderPoses();
    me('pose', { cmd });
}

// ---- a foto: a tela inteira (só o jogo) recortada na moldura ----
function crop(dataUrl) {
    return new Promise((resolve) => {
        const img = new Image();
        img.onload = () => {
            const r = $('frame').getBoundingClientRect();
            const sx = img.naturalWidth / window.innerWidth, sy = img.naturalHeight / window.innerHeight;
            const c = document.createElement('canvas');
            c.width = 480; c.height = 640;
            c.getContext('2d').drawImage(img, r.left * sx, r.top * sy, r.width * sx, r.height * sy, 0, 0, c.width, c.height);
            resolve(c.toDataURL('image/webp', 0.86));
        };
        img.onerror = () => resolve(null);
        img.src = dataUrl;
    });
}

async function shoot() {
    if (!open || !$('busy').hidden) return;
    $('busy').hidden = false;
    $('shoot').disabled = true;
    const r = await me('shoot');
    const cut = r && r.ok && r.shot ? await crop(r.shot) : null;
    $('busy').hidden = true;
    $('shoot').disabled = false;
    if (!cut) { $('busy').textContent = T.failed; $('busy').hidden = false; setTimeout(() => { $('busy').hidden = true; $('busy').textContent = T.busy; }, 2200); return; }
    photo = cut;
    $('shot').src = cut;
    $('preview').hidden = false;
}

function close() { if (open) me('close'); }

// ---- câmera pelo mouse: arrastar gira (horizontal) e sobe/desce (vertical); a roda aproxima ----
let drag = null, pending = { pan: 0, orbitX: 0, zoom: 0 }, sending = false;
function flush() {
    sending = false;
    if (!pending.pan && !pending.orbitX && !pending.zoom) return;
    const p = pending;
    pending = { pan: 0, orbitX: 0, zoom: 0 };
    cam({ pan: p.pan, orbitX: p.orbitX, zoom: p.zoom });
}
function queue() { if (!sending) { sending = true; setTimeout(flush, 32); } }

$('stage').addEventListener('contextmenu', (e) => e.preventDefault());
$('stage').addEventListener('mousedown', (e) => { drag = { x: e.clientX, y: e.clientY, ped: e.button === 2 }; $('stage').classList.add('dragging'); });
window.addEventListener('mousemove', (e) => {
    if (!drag) return;
    if (drag.ped) {
        spinBy((e.clientX - drag.x) * 0.5);   // botão direito: gira o personagem
    } else {
        pending.orbitX += e.clientX - drag.x;
        pending.pan += e.clientY - drag.y;
        queue();
    }
    drag = { x: e.clientX, y: e.clientY, ped: drag.ped };
});
window.addEventListener('mouseup', () => { drag = null; $('stage').classList.remove('dragging'); });
$('stage').addEventListener('wheel', (e) => { pending.zoom += Math.sign(e.deltaY); queue(); }, { passive: true });

// ---- girar o personagem: a câmera fica travada no mundo (CreatorCamera lock), só ele gira ----
let spinPending = 0, spinSending = false, spinHold = 0, spinTimer = null;
function spinBy(deg) {
    spinPending += deg;
    if (spinSending) return;
    spinSending = true;
    setTimeout(() => {
        spinSending = false;
        const g = Math.max(-45, Math.min(45, spinPending));
        spinPending = 0;
        if (g) me('girar', { graus: g });
    }, 32);
}
function spinStart(dir) {
    if (spinHold === dir) return;
    spinStop();
    spinHold = dir;
    spinTimer = setInterval(() => spinBy(dir * 4), 32);
    document.querySelectorAll('.spin-btn').forEach(b => b.classList.toggle('on', Number(b.dataset.spin) === dir));
}
function spinStop() {
    spinHold = 0;
    if (spinTimer) clearInterval(spinTimer);
    spinTimer = null;
    document.querySelectorAll('.spin-btn').forEach(b => b.classList.remove('on'));
}
document.addEventListener('mousedown', (e) => { const b = e.target.closest('.spin-btn'); if (b) spinStart(Number(b.dataset.spin)); });
window.addEventListener('mouseup', spinStop);
document.addEventListener('keyup', (e) => { const k = e.key.toLowerCase(); if (k === 'a' || k === 'd') spinStop(); });

// ---- cliques e teclas ----
document.addEventListener('click', (e) => {
    const t = e.target.closest('[data-tab],[data-cmd]');
    if (!t) return;
    if (t.dataset.tab != null) { tab = Number(t.dataset.tab); renderTabs(); renderPoses(); }
    else if (t.dataset.cmd != null) setPose(t.dataset.cmd);
});
$('search').addEventListener('input', renderPoses);
$('shoot').addEventListener('click', shoot);
$('back').addEventListener('click', close);
$('again').addEventListener('click', () => { $('preview').hidden = true; photo = null; });
$('use').addEventListener('click', () => { if (photo) me('save', { photo }); });

document.addEventListener('keydown', (e) => {
    if (!open) return;
    if (e.key === 'Escape') { if (!$('preview').hidden) { $('preview').hidden = true; photo = null; } else close(); return; }
    if (e.target && e.target.tagName === 'INPUT') { if (e.key === 'Enter') e.target.blur(); return; }
    if (e.key === 'Enter') { if (!$('preview').hidden) $('use').click(); else shoot(); return; }
    const k = e.key.toLowerCase();
    if ((k === 'a' || k === 'd') && $('preview').hidden) { spinStart(k === 'a' ? -1 : 1); return; }
    if (k === 'r' && $('preview').hidden) me('frente');   // de frente para a câmera de novo
});

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') {
        open = true;
        applyTexts(d.lang);
        categories = Array.isArray(d.categories) ? d.categories : [];
        tab = 0; pose = ''; photo = null;
        $('look-name').textContent = d.name || T.look;
        $('search').value = '';
        $('preview').hidden = true;
        $('busy').hidden = true;
        renderTabs(); renderPoses();
        $('studio').hidden = false;
    } else if (d.action === 'close') {
        open = false;
        spinStop();
        $('studio').hidden = true;
    }
});
