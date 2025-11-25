importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

// Initialize the Firebase app in the service worker by passing in the
// messagingSenderId.
firebase.initializeApp({
    apiKey: "AIzaSyBpjPbVzv1doRk7y5zsSiFTvYZNn6brcZc",
    authDomain: "caducidapp.firebaseapp.com",
    projectId: "caducidapp",
    storageBucket: "caducidapp.firebasestorage.app",
    messagingSenderId: "961732200215",
    appId: "1:961732200215:web:10a894c12ece1a65585952",
    measurementId: "G-P766X48NCY"
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
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
