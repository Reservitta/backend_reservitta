# Reservitta Email Server (Nodemailer + Gmail SMTP)

Microservicio ligero para enviar los comprobantes y recordatorios de reserva de **Reservitta** hacia cualquier correo destinatario (`@gmail.com`, `@outlook.com`, `@hotmail.com`, etc.) sin exponer credenciales en Flutter Web ni activar el plan de pago (Blaze) en Firebase.

## 1. Crear Contraseña de Aplicación en Google
1. Inicia sesión en la cuenta de Google que enviará los correos (ej. `reservitta.notificaciones@gmail.com`).
2. Ve a **Gestionar tu cuenta de Google → Seguridad**.
3. Activa la **Verificación en 2 pasos** si aún no está activa.
4. Entra a **Contraseñas de aplicaciones**, crea una nueva (ej. `Reservitta Render`) y copia la clave de 16 caracteres.

## 2. Desplegar gratis en Render
1. Crea una cuenta en [render.com](https://render.com) e inicia sesión con GitHub.
2. Haz clic en **New + → Web Service** y selecciona este repositorio.
3. Configura el servicio:
   - **Root Directory:** `email_server`
   - **Runtime:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Instance Type:** `Free`
4. En **Environment Variables**, agrega:
   - `GMAIL_USER` = tu correo de Gmail
   - `GMAIL_APP_PASSWORD` = la contraseña de aplicación de 16 caracteres
   - `EMAIL_FROM_NAME` = `Reservitta`
   - `ALLOWED_ORIGINS` = `https://reservitta-dev.web.app,https://reservitta-dev.firebaseapp.com`
   - `REQUIRE_FIREBASE_AUTH` = `true`
   - `FIREBASE_PROJECT_ID` = `reservitta-dev`
5. Despliega y copia la URL pública que te asigne Render (ej. `https://reservitta-email.onrender.com`).

## 3. Conectar Flutter (Web y Móvil)
Pasa la URL de tu servicio mediante `.env` o `--dart-define`:

```bash
flutter build web --release --dart-define=EMAIL_BACKEND_URL=https://reservitta-email.onrender.com
firebase deploy --only hosting
```

O en tu archivo `.env` local:
```env
EMAIL_BACKEND_URL=https://reservitta-email.onrender.com
```

