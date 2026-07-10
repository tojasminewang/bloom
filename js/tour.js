// tour.js — interactive walkthrough. Dims the app and spotlights the real sections,
// one at a time, with a little bubble explaining each. Gentle: 5 stops, skippable.
import { el } from './util.js';
import { sfx } from './audio.js';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const STEPS = [
  {
    route: '#/today', side: 'right',
    target: () => document.querySelector('#sidebar'),
    title: 'Getting around',
    text: 'Six little rooms — Today, Tasks, Calendar, Notes, Focus and Garden. Click any of them, any time.',
  },
  {
    route: '#/today',
    target: () => [...document.querySelectorAll('#view .card')].find((c) => c.textContent.includes('plan')),
    title: 'Today’s plan',
    text: 'Your day at a glance — tasks due today and any events. Type in the box to add a task.',
  },
  {
    route: '#/today',
    target: () => document.querySelector('#quicklog')?.closest('.card'),
    title: 'Add time',
    text: 'Already did something? Type it in plain words — like “30m piano” — and it still counts.',
  },
  {
    route: '#/focus',
    target: () => document.querySelector('#view .focus-hero'),
    title: 'The focus timer',
    text: 'Pick a plant, press start, do the thing. Every minute you focus makes that plant grow.',
  },
  {
    route: '#/garden',
    target: () => document.querySelector('.garden-banner') || document.querySelector('#view .card'),
    title: 'Your garden',
    text: 'Everything you grow lives here. Click a plant for details — and open the Plant book to see what they can become.',
  },
];

let root = null;

export function endTour() {
  root?.remove();
  root = null;
}

export function startTour() {
  endTour();
  const hole = el('div', { class: 'tour-hole' });
  const tip = el('div', { class: 'tour-tip' });
  root = el('div', { class: 'tour' }, hole, tip);
  document.body.append(root);
  show(0);

  async function show(idx) {
    const st = STEPS[idx];
    if (!root) return;
    if (location.hash !== st.route) {
      location.hash = st.route;
      await sleep(420); // let the router render the page
      if (!root) return;
    }
    const target = st.target();
    if (!target) { advance(idx); return; } // section missing? just move on
    target.scrollIntoView({ block: 'center' });
    await sleep(60);
    const r = target.getBoundingClientRect();
    const pad = 8;
    Object.assign(hole.style, {
      left: `${r.left - pad}px`, top: `${r.top - pad}px`,
      width: `${r.width + pad * 2}px`, height: `${r.height + pad * 2}px`,
    });

    const last = idx === STEPS.length - 1;
    tip.replaceChildren(
      el('div', { class: 'tour-kicker' }, `${idx + 1} of ${STEPS.length}`),
      el('h3', {}, st.title),
      el('p', {}, st.text),
      el('div', { class: 'tour-foot' },
        el('button', { class: 'link-btn', id: 'tour-skip', onClick: () => { sfx.click(); endTour(); } }, 'skip tour'),
        el('span', { class: 'spacer' }),
        el('button', {
          class: 'btn btn-primary', id: 'tour-next',
          onClick: () => { sfx.click(); advance(idx); },
        }, last ? 'Start growing' : 'Next'),
      ),
    );
    // place the bubble beside tall targets, else below (or above when cramped) — always clamped on-screen
    const vw = innerWidth, vh = innerHeight, m = 12;
    tip.style.visibility = 'hidden';
    await sleep(10);
    const tw = tip.offsetWidth, th = tip.offsetHeight;
    let left, top;
    if (st.side === 'right' && r.right + m + tw < vw) {
      left = r.right + m;
      top = Math.min(Math.max(r.top + r.height / 2 - th / 2, m), vh - th - m);
    } else {
      left = Math.min(Math.max(r.left + r.width / 2 - tw / 2, m), vw - tw - m);
      top = r.bottom + m + th < vh ? r.bottom + m : Math.max(r.top - th - m, m);
    }
    Object.assign(tip.style, { left: `${left}px`, top: `${top}px`, visibility: 'visible' });
  }

  function advance(idx) {
    if (idx + 1 >= STEPS.length) { endTour(); return; }
    show(idx + 1);
  }
}
