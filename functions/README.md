# Cloud Functions de Reservitta

Hacen en la nube lo que la app del administrador hace mientras está abierta:

| Función | Cuándo corre | Qué hace |
|---|---|---|
| `procesarOperaciones` | Cada minuto | Registra las alertas de llegada nuevas (HU30) y envía los recordatorios por correo que ya tocan (HU21). |
| `enviarPushAdmin` | Al crearse un documento en `restaurants/{id}/colaPush` | Envía el push (FCM) a los dispositivos de `restaurants/{id}/dispositivosAdmin`. |

`procesarOperaciones` solo atiende a los restaurantes con `configuracion.procesamientoServidor = true`
(se activa desde Dashboard → campana → "Procesar en el servidor"). Así la app y el servidor
nunca envían el mismo recordatorio dos veces.

## Despliegue

Requisitos: el proyecto `reservitta-dev` en el plan **Blaze**, Node 20 y la CLI de Firebase.

```bash
npm install -g firebase-tools
firebase login
```

1. Copia `functions/.env.example` a `functions/.env` y llena `RESEND_API_KEY` y `APP_URL`
   (sin clave de Resend, los correos se escriben en la colección `mail`).
2. Instala y despliega desde la raíz del repo:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions --project reservitta-dev
```

3. En la app, entra como administrador, abre los ajustes de alertas y activa "Procesar en el servidor".
4. Para el push en web, genera una clave VAPID en Firebase Console → Configuración del proyecto →
   Cloud Messaging → Certificados push web, y corre la app con `--dart-define=FCM_VAPID_KEY=<clave>`.
   En Android/iOS no hace falta (iOS requiere cargar la clave APNs en la misma pantalla).

## Pruebas

```bash
cd functions && npm test
```

Cubren la lógica de alertas, zona horaria y recordatorios (`src/logic.js`), que es la misma que usa la app.

## Límites

- El servidor solo envía los recordatorios por correo; las reservas sin correo se marcan como omitidas.
- Para ver los registros: `firebase functions:log`.
