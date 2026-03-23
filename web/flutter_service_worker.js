// Nuke service worker: se activa inmediatamente, borra todos los caches,
// y no intercepta ningún request. Una vez activo, el browser carga
// todo directo del servidor.
self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(names) {
      return Promise.all(names.map(function(name) {
        return caches.delete(name);
      }));
    }).then(function() {
      return self.clients.claim();
    }).then(function() {
      // Forzar recarga de todos los clientes activos
      return self.clients.matchAll({ type: 'window' }).then(function(clients) {
        clients.forEach(function(client) {
          client.navigate(client.url);
        });
      });
    })
  );
});

// No fetch handler = no intercepta requests = todo va directo al servidor
