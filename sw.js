// sw.js — Bloom's service worker: makes it installable + work offline.
// Strategy: precache the app shell, then stale-while-revalidate for same-origin
// GETs (serve cache instantly, refresh in the background). Cross-origin requests
// (Google Fonts, Supabase auth/sync) are left untouched — they always hit network.
const CACHE = 'bloom-v1';
const CORE = [
  './', 'index.html', 'css/style.css', 'manifest.webmanifest',
  'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (e) => {
  const { request } = e;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== location.origin) return; // fonts + Supabase go straight to network

  e.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request).then((res) => {
        if (res && res.status === 200 && res.type === 'basic') {
          const clone = res.clone();
          caches.open(CACHE).then((c) => c.put(request, clone));
        }
        return res;
      }).catch(() => cached || caches.match('index.html'));
      return cached || network;
    }),
  );
});
