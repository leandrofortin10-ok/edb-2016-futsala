importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCnCLB7glTXLw_xvAD30oayZflG_gnDTEk',
  authDomain: 'edb-estrella.firebaseapp.com',
  projectId: 'edb-estrella',
  storageBucket: 'edb-estrella.appspot.com',
  messagingSenderId: '259850372896',
  appId: '1:259850372896:web:12c891d2eb82e1b097f945',
});

const messaging = firebase.messaging();

// Handles push messages when the app is closed or in background
messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  if (!title) return;
  self.registration.showNotification(title, {
    body: body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  });
});

// Open/focus the app when the user taps the notification
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow('/');
    })
  );
});
