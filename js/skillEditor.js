// skillEditor.js — modal to plant a new skill or edit an existing one. Resolves to the skill or null.
import { el } from './util.js';
import { ic } from './icons.js';
import { store, uid, PALETTE, nextColor } from './store.js';
import { openModal, toast } from './ui.js';
import { plantSVG, SPECIES } from './plant.js';
import { levelOf } from './progress.js';
import { sfx } from './audio.js';

const ICONS = ['sprout', 'calc', 'book', 'code', 'globe', 'music', 'dumbbell', 'ball', 'palette', 'pencil', 'flask', 'cap', 'pan', 'gamepad', 'briefcase', 'film', 'camera', 'chat', 'heart', 'star', 'target', 'leaf', 'flower', 'pine'];

export function openSkillEditor(skill = null, { quiet = false } = {}) {
  return new Promise((resolve) => {
    let icon = skill?.icon || 'sprout';
    let species = skill?.species || 'bloom';
    let color = skill?.color || nextColor();
    let resolved = false;
    const finish = (val) => { if (!resolved) { resolved = true; resolve(val); } };

    const preview = el('div', { style: { textAlign: 'center' } });
    const renderPreview = () => {
      preview.innerHTML = plantSVG({ id: skill?.id || 'preview', color, species }, skill ? levelOf(skill.id).level : 4, 92);
    };
    renderPreview();

    const speciesRow = el('div', { class: 'species-row' });
    const renderSpecies = () => {
      speciesRow.replaceChildren(...Object.entries(SPECIES).map(([key, sp]) =>
        el('button', {
          class: 'species-cell' + (key === species ? ' sel' : ''), type: 'button', title: sp.label, dataset: { sp: key },
          onClick: () => { species = key; renderSpecies(); renderPreview(); sfx.click(); },
        },
          el('div', { html: plantSVG({ id: 'sp-' + key, color, species: key }, 6, 38) }),
          el('span', { class: 'species-name' }, sp.label),
        )));
    };
    renderSpecies();

    const nameIn = el('input', {
      class: 'input', id: 'skill-name-in', value: skill?.name || '',
      placeholder: 'e.g. Math, Piano, Spanish…', maxlength: 28,
      onKeydown: (e) => { if (e.key === 'Enter') save(); },
    });

    const iconGrid = el('div', { class: 'emoji-grid' });
    const iconCells = ICONS.map((name) =>
      el('button', {
        class: 'emoji-cell' + (name === icon ? ' sel' : ''), type: 'button',
        'aria-label': name, dataset: { icon: name },
        onClick: () => {
          icon = name;
          iconCells.forEach((c) => c.classList.toggle('sel', c.dataset.icon === name));
          sfx.click();
        },
      }, ic(name, { size: 17 })));
    iconGrid.append(...iconCells);

    const swatches = el('div', { class: 'swatches' });
    const swatchEls = PALETTE.map((c) =>
      el('button', {
        class: 'swatch' + (c === color ? ' sel' : ''), type: 'button', 'aria-label': 'color ' + c,
        style: { background: c },
        onClick: () => {
          color = c;
          swatchEls.forEach((s) => s.classList.toggle('sel', s.style.background && s.dataset.c === c));
          renderPreview();
          renderSpecies();
          sfx.click();
        },
        dataset: { c },
      }));
    swatches.append(...swatchEls);

    function save() {
      const name = nameIn.value.trim();
      if (!name) { nameIn.focus(); return; }
      if (skill) {
        Object.assign(skill, { name, icon, color, species });
        store.save();
        finish(skill);
      } else {
        const sk = { id: uid(), name, icon, color, species, createdAt: new Date().toISOString() };
        store.state.skills.push(sk);
        store.save(quiet);
        if (!quiet) toast(`${name} planted!`, 'pot');
        finish(sk);
      }
      close();
    }

    const close = openModal(
      el('div', {},
        el('h2', { style: { marginBottom: '4px' } }, ...(skill ? ['Edit ', el('em', {}, 'plant')] : ['Plant a new ', el('em', {}, 'skill')])),
        el('p', { class: 'muted small', style: { marginBottom: '10px' } }, skill ? '' : 'Anything you want to get better at — it becomes a plant in your garden.'),
        preview,
        el('div', { class: 'field-label' }, 'Name'),
        nameIn,
        el('div', { class: 'field-label' }, 'Species'),
        speciesRow,
        el('div', { class: 'field-label' }, 'Icon'),
        iconGrid,
        el('div', { class: 'field-label' }, 'Pot color'),
        swatches,
        el('div', { class: 'row gap', style: { marginTop: '20px', justifyContent: 'flex-end' } },
          el('button', { class: 'btn btn-primary btn-big', onClick: save }, skill ? 'Save' : 'Plant it'),
        ),
      ),
      { onClose: () => finish(null) },
    );
    setTimeout(() => nameIn.focus(), 60);
  });
}

// Shared <select> of skills with a "plant new" option. Creates quietly (no global
// re-render) so surrounding form drafts survive; caller gets the new id via onChange.
export function skillSelect({ value = '', allowNone = true, noneLabel = 'no plant', onChange, id } = {}) {
  let current = value || '';
  const sel = el('select', { class: 'input' });
  if (id) sel.id = id;
  const rebuild = () => {
    sel.innerHTML = '';
    if (allowNone) sel.append(el('option', { value: '' }, noneLabel));
    for (const sk of store.state.skills) sel.append(el('option', { value: sk.id }, sk.name));
    sel.append(el('option', { value: '__new' }, '＋ Plant new skill…'));
    sel.value = current;
  };
  rebuild();
  sel.addEventListener('change', async () => {
    if (sel.value === '__new') {
      const sk = await openSkillEditor(null, { quiet: true });
      if (sk) {
        current = sk.id;
        toast(`${sk.name} planted!`, 'pot');
        onChange?.(sk.id);
      }
      rebuild();
    } else {
      current = sel.value;
      onChange?.(sel.value || null);
    }
  });
  return sel;
}
