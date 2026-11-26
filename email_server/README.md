# Reservitta Email Server (Brevo HTTP API)

Microservicio ligero para enviar los comprobantes y recordatorios de reserva de **Reservitta** hacia cualquier correo destinatario (`@gmail.com`, `@outlook.com`, `@hotmail.com`, etc.) por HTTPS (puerto 443, compatible con el plan gratuito de Render) sin necesidad de dominio propio.

## 1. Configurar Brevo (Gratis: 300 correos/día)
1. Crea una cuenta gratuita en [brevo.com](https://www.brevo.com).
2. Ve a **Senders, Domains & Dedicated IPs → Senders → Add a sender** y agrega/verifica tu correo de Gmail (te llegará un código de verificación a ese Gmail).
3. Ve a **SMTP & API → API Keys → Generate a new API key** y copia la clave (`xkeysib-...`).

## 2. Variables de entorno en Render
En tu Web Service de Render (**Root Directory:** `email_server`), configura:
- `BREVO_API_KEY` = tu clave `xkeysib-...`
- `BREVO_SENDER_EMAIL` = el correo Gmail que verificaste en Brevo *(o `GMAIL_USER` si ya la tenías)*
- `EMAIL_FROM_NAME` = `Reservitta`
- `ALLOWED_ORIGINS` = `https://reservitta-dev.web.app,https://reservitta-dev.firebaseapp.com`
- `REQUIRE_FIREBASE_AUTH` = `true`
- `FIREBASE_PROJECT_ID` = `reservitta-dev`

## 3. Conectar Flutter (Web y Móvil)
```bash
flutter build web --release --dart-define=EMAIL_BACKEND_URL=https://backend-reservitta.onrender.com
npx firebase-tools deploy --only hosting
```
