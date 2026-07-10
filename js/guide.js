// guide.js — paged "how Bloom works" tour. Opened from the ? button, and once after onboarding.
// Kept deliberately simple: plain words, three short pages, no jargon (no "XP", no "skill").
import { el } from './util.js';
import { openModal } from './ui.js';
import { plantSVG } from './plant.js';
import { ic } from './icons.js';

const demoSkill = { id: 'guide-demo', name: 'Math', color: '#C97F5F' };

function iconLine(name, title, body) {
  return el('div', { class: 'guide-line' },
    el('span', { class: 'guide-line-ic' }, ic(name, { size: 17 })),
    el('div', {},
      el('div', { class: 'guide-line-title' }, title),
      el('div', { class: 'muted small' }, body),
    ),
  );
}

function pages() {
  return [
    {
      title: ['Grow a little ', el('em', {}, 'garden')],
      body: el('div', {},
        el('div', { class: 'guide-plants' },
          ...[[1, 'sprout'], [4, 'bud'], [8, 'bloom'], [12, 'radiant']].map(([lv, label]) =>
            el('div', { class: 'guide-plant' },
              el('div', { html: plantSVG(demoSkill, lv, 62) }),
              el('div', { class: 'guide-plant-label' }, label),
            )),
        ),
        el('p', { class: 'guide-p' }, 'Anything you want to spend time on — piano, math, reading — becomes a little plant. ', el('b', {}, 'Give it minutes, and it grows.'), ' That’s the whole idea.'),
      ),
    },
    {
      title: ['Two ways to ', el('em', {}, 'water')],
      body: el('div', {},
        iconLine('hourglass', 'Use the timer', 'On the Focus page: pick your plant, press start, do the thing. Bloom counts the minutes for you.'),
        iconLine('bolt', 'Or just type it', 'Did something without the timer? Type it in plain words — it still counts.'),
        el('div', { class: 'row gap wrap', style: { margin: '2px 0 12px 40px' } },
          el('span', { class: 'chip green' }, '“1h math”'),
          el('span', { class: 'chip green' }, '“30m piano yesterday”'),
        ),
        el('p', { class: 'muted small', style: { marginTop: '6px' } }, 'Minutes in, growth out — that’s honestly all there is to it.'),
      ),
    },
    {
      title: ['A few nice ', el('em', {}, 'extras')],
      body: el('div', {},
        iconLine('check-square', 'Tasks & calendar', 'Plan your day if you like — finishing a task feeds its plant a little too.'),
        iconLine('note', 'Notes', 'Jot anything down. They save themselves.'),
        iconLine('flame', 'Streak', 'Show up each day — even a few minutes — and your streak keeps climbing.'),
        el('p', { class: 'muted small', style: { marginTop: '10px' } }, 'Explore at your own pace — nothing here needs setting up. The ? button brings this guide back any time.'),
      ),
    },
  ];
}

export function openGuide() {
  let idx = 0;
  const wrap = el('div', { class: 'guide' });
  const close = openModal(wrap);

  function renderPage() {
    const pg = pages()[idx];
    const last = idx === pages().length - 1;
    wrap.replaceChildren(
      el('div', { class: 'guide-head' },
        el('span', { class: 'guide-kicker' }, 'HOW BLOOM WORKS'),
        el('h2', {}, ...pg.title),
      ),
      pg.body,
      el('div', { class: 'guide-foot' },
        el('div', { class: 'guide-dots' },
          ...pages().map((_, i) => el('span', { class: 'guide-dot' + (i === idx ? ' on' : ''), onClick: () => { idx = i; renderPage(); } })),
        ),
        el('span', { class: 'spacer' }),
        idx > 0 ? el('button', { class: 'btn', onClick: () => { idx--; renderPage(); } }, 'Back') : null,
        el('button', {
          class: 'btn btn-primary', id: 'guide-next',
          onClick: () => { if (last) close(); else { idx++; renderPage(); } },
        }, last ? 'Start growing' : 'Next'),
      ),
    );
  }
  renderPage();
}
