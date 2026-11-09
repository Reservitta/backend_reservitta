// Service worker de Firebase Cloud Messaging (web): muestra las alertas de llegada
// cuando la pestaña del administrador está cerrada o en segundo plano (HU30-RF02).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Configuración pública del cliente web (la misma de lib/firebase_options.dart).
firebase.initializeApp({
  apiKey: 'AIzaSyAuBzM8uNCeU1Twd1R3MXumreqn_7CqNT4',
  appId: '1:57296769818:web:40de73d126f4778c5712a3',
  messagingSenderId: '57296769818',
  projectId: 'reservitta-dev',
  authDomain: 'reservitta-dev.firebaseapp.com',
  storageBucket: 'reservitta-dev.firebasestorage.app',
});

// Con el campo `notification` el navegador ya muestra el aviso; esto cubre los
// mensajes que lleguen solo con datos.
const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const datos = payload.data || {};
  self.registration.showNotification(datos.titulo || 'Reservitta', {
    body: datos.cuerpo || '',
  });
});
