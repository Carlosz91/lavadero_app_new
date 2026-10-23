# 🚗 Lavadero App

Aplicación móvil para la gestión de lavaderos de vehículos. Permite registrar autos, seguir el estado del lavado en tiempo real, pagar en línea y administrar el flujo de trabajo.

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3.35.2 / Dart 3.9.0 |
| Backend | Node.js / Express |
| Base de datos | MongoDB |
| Autenticación | JWT (access 1h + refresh 7d) |
| Email | Nodemailer (SMTP opcional) |

## Funcionalidades

- **Registro de vehículos** — cualquier usuario autenticado puede registrar un auto con placa, modelo, marca, color y tipo de lavado
- **Agendamiento** — selección de fecha y hora al registrar, con control de capacidad (máximo 5 autos por día, server-side)
- **Estado del lavado** — seguimiento con filtros por estado (Pendiente, En Progreso, Completado, Cancelado) y progreso derivado del estado real
- **Pagos** — los usuarios pagan **solo con Stripe Checkout**; Efectivo/Tarjeta/Transferencia los registra el staff/admin desde el panel (el usuario no puede autoproclamar pagos → 403)
- **Pago pendiente** — al completar el lavado se genera un pago; bloquea nuevo registro si hay deuda
- **Recuperación de contraseña** — `POST /api/auth/forgot-password` envía un código por email (SMTP opcional; sin SMTP, en desarrollo el código queda en los logs) y `POST /api/auth/reset-password` permite restablecer con código de un solo uso (15 min)
- **Modo oscuro** — toggle real en Ajustes, persistente, con paleta mutable (`AppColors.apply`)
- **Bloqueo biométrico** — bloqueo de app con huella/rostro/PIN del dispositivo (`local_auth`), verificable al activar y al volver del segundo plano
- **Panel admin** — `http://localhost:5000/admin/` (login JWT, auto-refresh, auto-logout al expirar, salida HTML escapada)
- **Roles** — `admin`/`staff` pueden cambiar estados y marcar pagos; `user` solo registra, agenda, consulta y paga con Stripe
- **Primer usuario** registrado se convierte en `admin` automáticamente
- **Sistema de diseño** — tema personalizado claro/oscuro con colores, tipografía y componentes reutilizables
- **Animaciones** — fondo con gotas animadas, logo flotante, fade-in escalonado en todas las pantallas
- **API REST** documentada con Swagger en `http://localhost:5000/api/docs`
- **Seguridad** — JWT con claim `type` (access/refresh separados), renovación automática de sesión ante 401, Helmet CSP, rate limiting, sanitize, validación, bloqueo por fuerza bruta, idempotencia en POST (Idempotency-Key), CORS con allowlist por defecto

## Instalación

### Requisitos

- Flutter 3.35.2+
- Node.js 18+
- MongoDB (local o Atlas)

### Backend

```bash
cd car_wash_backend
cp .env.example .env   # editar MONGO_URI, JWT_SECRET, JWT_REFRESH_SECRET
npm install
npm start
```

Variables opcionales: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `GOOGLE_CLIENT_ID` (obligatorio en producción para Google Sign-In), `SMTP_*` para el envío de emails de recuperación y `APP_RESET_URL`.

### Frontend

```bash
flutter pub get
flutter run
```

Para Google Sign-In se puede configurar el server client id con `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` (hay un default de desarrollo).

### Build release con ofuscación

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

- `--obfuscate` renombra símbolos de Dart para dificultar la ingeniería inversa
- `--split-debug-info` guarda los mapas de símbolos (necesarios para leer stack traces)
- Los símbolos se envían al backend (`.symbols` en el reporte de errores); no deben publicarse

## Seguridad

- **Precios server-side**: el cliente no envía montos; el backend calcula el precio desde `config/priceCatalog.js` (fuente de verdad) e ignora `amount` recibido
- **Catálogo centralizado**: `GET /api/cars/prices` público para que la app muestre precios sin confiarlos
- **Pagos**: `PUT /api/payments/:id` exclusivo de admin/staff; el checkout de Stripe toma el monto del pago existente (`paymentId`)
- **Rate limits**: límites por IP (global), por usuario (10 registros/hora en `registercar`) y de recuperación de contraseña (5/hora)
- **Idempotencia**: `Idempotency-Key` requerida en POST con replay 24h en MongoDB
- **Credenciales**: token, refresh token y `userId` en FlutterSecureStorage (fuente de verdad; migración automática desde SharedPreferences)
- **Reset de contraseña**: el token se guarda hasheado (sha256) y expira en 15 minutos; la respuesta es genérica para evitar enumeración de usuarios
- **Dependencias**: `npm audit --omit=dev` → 0 vulnerabilidades en el árbol de producción (las restantes son solo tooling dev: jest/nodemon, esperando parches upstream)

### Crear admin manualmente

```bash
node car_wash_backend/scripts/seedAdmin.js email@correo.com Password123
```

## Probar

```bash
cd car_wash_backend
npm test
```

60 tests con Jest: login/registro/Google, refresh (incluye rechazo de access token como refresh), forgot/reset-password completo con `mailer.outbox`, autos, pagos (403 al dueño, 200 al admin), admin y Stripe.

```bash
flutter test      # widget test del flujo de login
flutter analyze   # 0 issues
```

## Estructura

```
lib/
├── screens/          # pantallas (login, register, forgot/reset-password, home, register-car, wash-status, payments, lock, settings, about)
├── widgets/          # componentes reutilizables (GradientAppBar, StatusBadge, WaterBackground, StaggeredFadeIn, etc.)
├── theme/            # sistema de diseño claro/oscuro (AppColors mutable, AppTextStyles, AppTheme)
├── services/         # http, theme controller, app lock (biometría)
├── utils/            # formatters compartidos (moneda, fechas, email)
└── config/           # API config (endpoints centralizados)

car_wash_backend/
├── controllers/      # lógica de negocio (auth, cars, payments, stripe)
├── middlewares/      # auth, validación, sanitize, rate limit, error handler
├── models/           # esquemas MongoDB (User, Car, Payment)
├── routes/           # definición de rutas REST
├── utils/            # logger (Winston), AppError, requestId, mailer (Nodemailer)
├── scripts/          # seedAdmin.js
├── __tests__/        # 60 tests con Jest (supertest + mongodb-memory-server)
└── admin-panel/      # panel web HTML con login JWT + auto-refresh

docs/                 # notas de diseño e implementación (MDs históricos)
```

## Licencia

© 2024 Carlos Z. Todos los derechos reservados.
