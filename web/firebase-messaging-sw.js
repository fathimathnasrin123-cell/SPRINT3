importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyBKoB9XRPy-pmnBeqy836b8fd_qyx8G-0E",
    authDomain: "carenow-19214.firebaseapp.com",
    projectId: "carenow-19214",
    storageBucket: "carenow-19214.firebasestorage.app",
    messagingSenderId: "1093768617024",
    appId: "1:1093768617024:web:031404b1071933feb193a5",
    measurementId: "G-SP1SQRR1FF"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    // Customize notification here
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle,
        notificationOptions);
});
