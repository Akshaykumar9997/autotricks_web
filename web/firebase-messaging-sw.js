// Web FCM Service Worker for AutoTricks
importScripts("https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js");

// Initialize Firebase using values from firebase_options.dart
firebase.initializeApp({
  apiKey: "AIzaSyAm86I062dZ_cwpyTMwWwPKjMGDcOOgtNU",
  appId: "1:170776275984:web:82347860baf2fb9abb6e95",
  messagingSenderId: "170776275984",
  projectId: "autotricks-6485f",
  authDomain: "autotricks-6485f.firebaseapp.com",
  storageBucket: "autotricks-6485f.firebasestorage.app",
});

const messaging = firebase.messaging();

// Background push notification handler for Web
messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message:", payload);
  const notificationTitle =
      payload.notification?.title || payload.data?.title || "AutoTricks Notification";
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.message || "",
    icon: "/icons/Icon-192.png",
    data: payload.data || {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
