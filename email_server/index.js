require('dotenv').config();

const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const app = express();
const PORT = process.env.PORT || 3000;

const projectId = process.env.FIREBASE_PROJECT_ID || 'reservitta-dev';
if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const defaultAllowedOrigins = [
  'https://reservitta-dev.web.app',
  'https://reservitta-dev.firebaseapp.com',
];

const extraOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

const allowedOrigins = new Set([...defaultAllowedOrigins, ...extraOrigins]);

app.use(
  cors({
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (allowedOrigins.has(origin) || /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
        return callback(null, true);
      }
      return callback(new Error(`Origen no permitido por CORS: ${origin}`));
    },
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

app.use(express.json({ limit: '1mb' }));

async function verifyFirebaseAuth(req, res, next) {
  const requireAuth = (process.env.REQUIRE_FIREBASE_AUTH || 'true').toLowerCase() !== 'false';
  const authHeader = req.headers.authorization || '';
  const match = authHeader.match(/^Bearer\s+(.+)$/i);

  if (!match) {
    if (!requireAuth) return next();
    return res.status(401).json({
      ok: false,
      error: 'No autorizado: falta el token de Firebase Auth.',
    });
  }

  try {
    const decoded = await admin.auth().verifyIdToken(match[1]);
    req.firebaseUser = decoded;
    return next();
  } catch (err) {
    return res.status(401).json({
      ok: false,
      error: 'Token de Firebase Auth inválido o expirado.',
    });
  }
}

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'reservitta-email-server' });
});

app.post('/api/send-confirmation', verifyFirebaseAuth, async (req, res) => {
  try {
    const { to, subject, text, html } = req.body || {};

    const cleanTo = typeof to === 'string' ? to.trim().toLowerCase() : '';
    if (!cleanTo || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanTo)) {
      return res.status(400).json({
        ok: false,
        error: 'Dirección de correo electrónico destinataria inválida.',
      });
    }

    const cleanSubject = typeof subject === 'string' ? subject.trim() : '';
    if (!cleanSubject) {
      return res.status(400).json({
        ok: false,
        error: 'El asunto del correo es obligatorio.',
      });
    }

    const cleanText = typeof text === 'string' ? text : '';
    const cleanHtml = typeof html === 'string' ? html : '';
    if (!cleanText.trim() && !cleanHtml.trim()) {
      return res.status(400).json({
        ok: false,
        error: 'El contenido del correo es obligatorio.',
      });
    }

    const brevoApiKey = (process.env.BREVO_API_KEY || '').trim();
    const senderEmail = (process.env.BREVO_SENDER_EMAIL || process.env.GMAIL_USER || '').trim();
    const senderName = (process.env.EMAIL_FROM_NAME || 'Reservitta').trim();

    if (!brevoApiKey || !senderEmail) {
      return res.status(500).json({
        ok: false,
        error: 'Faltan las variables BREVO_API_KEY o BREVO_SENDER_EMAIL en el servidor.',
      });
    }

    const brevoResponse = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        accept: 'application/json',
        'content-type': 'application/json',
        'api-key': brevoApiKey,
      },
      body: JSON.stringify({
        sender: { name: senderName, email: senderEmail },
        to: [{ email: cleanTo }],
        subject: cleanSubject,
        textContent: cleanText || undefined,
        htmlContent: cleanHtml || undefined,
      }),
    });

    const data = await brevoResponse.json().catch(() => ({}));

    if (!brevoResponse.ok) {
      console.error(`[email-server] Error Brevo (${brevoResponse.status}):`, data);
      return res.status(brevoResponse.status).json({
        ok: false,
        error: data.message || `Error al enviar correo con Brevo (Status ${brevoResponse.status})`,
      });
    }

    console.log(`[email-server] Correo enviado a ${cleanTo} (messageId: ${data.messageId || 'ok'})`);
    return res.status(200).json({
      ok: true,
      messageId: data.messageId || 'sent',
    });
  } catch (error) {
    console.error('[email-server] Error al enviar correo:', error.message);
    return res.status(500).json({
      ok: false,
      error: `Error interno al enviar correo: ${error.message}`,
    });
  }
});

app.listen(PORT, () => {
  console.log(`[email-server] Escuchando en el puerto ${PORT}`);
});
