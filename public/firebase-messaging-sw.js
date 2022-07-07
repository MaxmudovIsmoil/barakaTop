importScripts('https://www.gstatic.com/firebasejs/8.3.0/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.3.0/firebase-messaging.js');

	firebase.initializeApp({
        apiKey: "AIzaSyBf4ZqENl_Noe6v9LrH7jCrK1vjWFfkAFA",
        authDomain: "laravel-firebase-app-9d9ca.firebaseapp.com",
        projectId: "laravel-firebase-app-9d9ca",
        storageBucket: "laravel-firebase-app-9d9ca.appspot.com",
        messagingSenderId: "324803386436",
        appId: "1:324803386436:web:374888956c99863b1b7011",
        // databaseURL: "https://Your_Project_ID.firebaseio.com",
        measurementId: "G-HYMMVELHT8"
    });

	const messaging = firebase.messaging();
	messaging.setBackgroundMessageHandler(function(payload) {
    console.log(
        "[firebase-messaging-sw.js] Received background message ",
        payload,
    );

    const notificationTitle = "Background Message Title";
    const notificationOptions = {
        body: "Background Message body.",
        icon: "/itwonders-web-logo.png",
    };

    return self.registration.showNotification(
        notificationTitle,
        notificationOptions,
    );
});
