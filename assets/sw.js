// sw.js - Boss Monster service worker.
//
// Strategy:
//   - App shell (/, /index.html): network-first, fall back to cache (so a new
//     deploy is picked up, but the game still loads offline).
//   - Static assets (/apk_cards, /ui, /audio, /fonts, hashed /assets): cache-first
//     with background fill — these are immutable local files, ideal for offline.
//   - Socket.IO / lobby API: never cached (real-time + server authority).
const CACHE = 'boss-monster-v1';
const SHELL = ['/', '/index.html', '/manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  // Never intercept real-time / API traffic.
  if (url.pathname.startsWith('/socket.io') || url.pathname.startsWith('/lobby')) return;

  const isStatic =
    url.pathname.startsWith('/apk_cards/') ||
    url.pathname.startsWith('/ui/') ||
    url.pathname.startsWith('/audio/') ||
    url.pathname.startsWith('/fonts/') ||
    url.pathname.startsWith('/assets/');

  if (isStatic) {
    // Cache-first for immutable local assets.
    event.respondWith(
      caches.match(req).then((hit) => {
        const fetchAndCache = fetch(req)
          .then((res) => {
            if (res && res.ok) {
              const clone = res.clone();
              caches.open(CACHE).then((cache) => cache.put(req, clone));
            }
            return res;
          })
          .catch(() => hit);
        return hit || fetchAndCache;
      })
    );
    return;
  }

  // Network-first for the app shell / navigation.
  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res && res.ok) {
          const clone = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, clone));
        }
        return res;
      })
      .catch(() => caches.match(req).then((hit) => hit || caches.match('/index.html')))
  );
});
