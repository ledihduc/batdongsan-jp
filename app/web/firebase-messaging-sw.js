// firebase-messaging-sw.js
// FCM background message handler for ancu365 web (PWA)
// Version: Phase 5 — finalized notificationclick with deep-link routing
//
// IMPORTANT: This file must remain at /web/firebase-messaging-sw.js (root).
// Firebase enforces this exact path for the service worker scope.
//
// TODO ops: Replace all __PLACEHOLDER__ values with real Firebase Console config.
//   Go to: Firebase Console → Project Settings → General → Your apps → Web app → Config

// Use compat SDK v10.13.0 (matches index.html script tags)
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

// TODO ops: Replace placeholder values below with real Firebase project config
const firebaseConfig = {
  apiKey: "__FIREBASE_API_KEY__",
  authDomain: "__FIREBASE_AUTH_DOMAIN__",
  projectId: "__FIREBASE_PROJECT_ID__",
  storageBucket: "__FIREBASE_STORAGE_BUCKET__",
  messagingSenderId: "__FIREBASE_MESSAGING_SENDER_ID__",
  appId: "__FIREBASE_APP_ID__",
};

// Initialize only if config has been replaced (prevents crash with placeholder values)
if (firebaseConfig.apiKey && !firebaseConfig.apiKey.startsWith('__')) {
  firebase.initializeApp(firebaseConfig);

  const messaging = firebase.messaging();

  // Background message handler: called when app is not in foreground
  // payload.notification contains { title, body }
  // payload.data contains custom key-value pairs from BE
  messaging.onBackgroundMessage(function(payload) {
    console.log('[firebase-messaging-sw.js] Background message received:', payload);

    const notificationTitle = payload.notification?.title || 'ancu365';
    const notificationOptions = {
      body: payload.notification?.body || '',
      // Icon must be a file accessible in web/ directory
      icon: '/icons/Icon-192.png',
      // Badge shown in notification bar (Android Chrome)
      badge: '/icons/Icon-192.png',
      // Custom data passed through to notificationclick handler.
      // BE may include click_action for deep-link routing.
      data: payload.data || {},
    };

    // showNotification is required in service worker context (no DOM access)
    return self.registration.showNotification(notificationTitle, notificationOptions);
  });

  // Handle notification click:
  //   1. Post a message to all active Flutter Web clients so the app can route.
  //   2. Focus an existing window on the target URL, or open a new one.
  self.addEventListener('notificationclick', function(event) {
    event.notification.close();

    // click_action from BE payload takes precedence; fall back to app root.
    const targetUrl = event.notification.data?.click_action || '/';
    const notificationData = event.notification.data || {};

    event.waitUntil(
      clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
        // Post message to all active clients so Flutter Web can route without
        // waiting for a new window to load. The Flutter app listens via
        // window.addEventListener('message', ...) or ServiceWorkerRegistration
        // postMessage handler (wired in NotificationProvider.attachFcm).
        for (const client of clientList) {
          client.postMessage({
            type: 'notification_tap',
            data: notificationData,
          });
        }

        // Focus existing tab if it already has the target URL open.
        for (const client of clientList) {
          if (client.url.includes(targetUrl) && 'focus' in client) {
            return client.focus();
          }
        }

        // No matching tab found — open a new window at the target URL.
        if (clients.openWindow) {
          return clients.openWindow(targetUrl);
        }
      })
    );
  });
} else {
  // Config not yet set by ops — log clearly so developer knows action is needed
  console.warn(
    '[firebase-messaging-sw.js] Firebase config not initialized: placeholder values detected. ' +
    'Replace __PLACEHOLDER__ values in web/firebase-messaging-sw.js with real Firebase config. ' +
    'See docs/features/permission-priming-config.md for instructions.'
  );
}
