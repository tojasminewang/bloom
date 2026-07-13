// reminders.js — a gentle daily nudge to come water your garden.
// Honest about the platform: a static web app can only remind you while Bloom is
// open (even in a background tab) or the moment you next open it. When the tab is
// alive at your chosen time we fire a real browser notification; otherwise you get
// an in-app nudge on your next visit. True closed-app push would need a server.
import { store } from './store.js';
import { todayYmd, pad2 } from './util.js';
import { activeOn, streak } from './progress.js';
import { toast } from './ui.js';
import { sfx } from './audio.js';

const nowHHMM = () => { const d = new Date(); return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`; };

export const notifySupported = () => 'Notification' in window;
export const notifyPermission = () => (notifySupported() ? Notification.permission : 'unsupported');

// Ask the browser for permission; resolves to the resulting permission string.
export async function requestNotify() {
  if (!notifySupported()) return 'unsupported';
  if (Notification.permission !== 'default') return Notification.permission;
  try { return await Notification.requestPermission(); } catch { return Notification.permission; }
}

function nudgeMessage() {
  const st = streak();
  if (st >= 2) return { title: `Keep your ${st}-day streak alive 🌱`, body: 'A few focused minutes today keeps your garden growing.' };
  return { title: 'Your garden is thirsty 🌱', body: 'A little water today — even five minutes counts.' };
}

// Fire the nudge once for today: browser notification if allowed, plus an in-app toast
// when the tab is visible. Only mark today done once we've actually shown something —
// so a denied-permission user backgrounded at reminder time still gets nudged on return.
function fireNudge() {
  const s = store.state.settings;
  const today = todayYmd();
  if (s.reminderLast === today) return; // already nudged today

  const { title, body } = nudgeMessage();
  let delivered = false;
  if (notifyPermission() === 'granted') {
    try { new Notification(title, { body, tag: 'bloom-reminder', silent: false }); delivered = true; } catch { /* fine */ }
  }
  if (!document.hidden) { sfx.pop(); toast(title, 'sprout'); delivered = true; }
  if (delivered) { s.reminderLast = today; store.save(true); }
}

// Should we nudge right now? On if enabled, past the set time, nothing grown today.
function due() {
  const s = store.state.settings;
  if (!s.reminder) return false;
  if (activeOn(todayYmd())) return false;      // already grew something today — no nudge needed
  if (s.reminderLast === todayYmd()) return false;
  return nowHHMM() >= (s.reminderTime || '19:00');
}

function tick() { if (due()) fireNudge(); }

let timer = null;
export function initReminders() {
  clearInterval(timer);
  timer = setInterval(tick, 60 * 1000); // check every minute while open
  document.addEventListener('visibilitychange', () => { if (!document.hidden) tick(); });
  tick(); // and once right now, in case they open Bloom past reminder time
}
