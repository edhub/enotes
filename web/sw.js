'use strict';

// Bump this string whenever you need to force all clients to re-fetch
// everything (e.g. after a breaking change in the app shell).
const CACHE = 'enotes-v1';

// Files fetched and cached on the first install.
// sqlite3.wasm is listed here so the app works fully offline after install.
const PRECACHE = [
  './',
  'index.html',
  'flutter.js',
  'flutter_bootstrap.js',
  'main.dart.js',
  'sqlite3.wasm',
  'manifest.json',
  'favicon.png',
  'version.json',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'assets/AssetManifest.bin',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
];

// ── Install ───────────────────────────────────────────────────────────────────

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => Promise.allSettled(PRECACHE.map((url) => cache.add(url).catch(() => {}))))
      .then(() => self.skipWaiting())
  );
});

// ── Activate ──────────────────────────────────────────────────────────────────

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((k) => k.startsWith('enotes-') && k !== CACHE)
          .map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

// ── Fetch ─────────────────────────────────────────────────────────────────────

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  if (url.origin !== location.origin) return; // don't intercept CDN / API calls

  const path = url.pathname.replace(/^\/+/, '') || 'index.html';

  // Large/stable assets — cache-first, no network round-trip on hit.
  if (
    path === 'sqlite3.wasm' ||
    path.startsWith('canvaskit/') ||
    path.startsWith('assets/fonts/')
  ) {
    event.respondWith(cacheFirst(event.request));
    return;
  }

  // Everything else — serve cached copy instantly, refresh in background.
  event.respondWith(staleWhileRevalidate(event.request));
});

// ── Strategies ────────────────────────────────────────────────────────────────

async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    return new Response('Offline', { status: 503 });
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request);

  // Always kick off a background refresh regardless of cache hit.
  const networkFetch = fetch(request)
    .then((response) => {
      if (response.ok) cache.put(request, response.clone());
      return response;
    })
    .catch(() => null);

  // Return cached immediately if available, otherwise wait for network.
  return cached ?? (await networkFetch) ?? new Response('Offline', { status: 503 });
}
