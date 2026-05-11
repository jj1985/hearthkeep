// HEARTHKEEP service worker — cache-first for the static bundle.
const CACHE = 'hearthkeep-v1';
const ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './src/style.css',
  './src/main.js',
  './src/game.js',
  './src/state.js',
  './src/save.js',
  './src/perks.js',
  './src/upgrades.js',
  './src/achievements.js',
  './src/synergies.js',
  './src/sfx.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).catch(() => null));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  e.respondWith(
    caches.match(req).then((cached) =>
      cached ||
      fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => null);
        return res;
      }).catch(() => cached || Response.error())
    )
  );
});
