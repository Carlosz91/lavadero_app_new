# 🚗 Lavadero App

Aplicación móvil para la gestión de lavaderos de vehículos. Permite registrar autos, seguir el estado del lavado en tiempo real, gestionar pagos y administrar el flujo de trabajo.

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter 3.35.2 / Dart 3.9.0 |
| Backend | Node.js / Express |
| Base de datos | MongoDB |
| Autenticación | JWT |

## Funcionalidades

- **Registro de vehículos** — cualquier usuario autenticado puede registrar un auto con placa, modelo, marca y tipo de lavado
- **Agendamiento** — selección de fecha y hora al registrar, con control de capacidad (máximo 5 autos por día)
- **Estado del lavado** — seguimiento en tiempo real con filtros por estado (Pendiente, En Progreso, Completado, Cancelado)
- **Gestión de pagos** — registro y consulta de pagos (Efectivo, Tarjeta, Transferencia, Mercado Pago)
- **Mercado Pago** — integración con checkout de Mercado Pago en modo test (tarjetas de prueba)
- **Panel admin** — `http://localhost:5000/admin/` (login JWT, solo admin/staff cambia estados)
- **Roles** — `admin`/`staff` pueden cambiar estados; `user` solo registra, agenda y consulta
- **Primer usuario** registrado se convierte en `admin` automáticamente
- **Sistema de diseño** — tema personalizado con colores, tipografía y 9 componentes reutilizables
- **API REST** documentada con Swagger en `http://localhost:5000/api-docs`
- **Seguridad** — JWT, Helmet CSP, rate limiting, sanitize, validación, bloqueo por fuerza bruta

## Instalación

### Requisitos

- Flutter 3.35.2+
- Node.js 18+
- MongoDB (local o Atlas)

### Backend

```bash
cd car_wash_backend
cp .env.example .env   # editar MONGO_URI y JWT_SECRET
npm install
npm start
```

### Frontend

```bash
flutter pub get
flutter run
```

### Crear admin manualmente

```bash
node car_wash_backend/scripts/seedAdmin.js email@correo.com Password123
```

## Probar

```bash
cd car_wash_backend
npm test
```

49 tests, ~85% de cobertura.

## Estructura

```
lib/
├── screens/          # 10 pantallas (login, register, forgot-password, home, register-car, wash-status, payments, settings, about)
├── widgets/          # 9 componentes reutilizables (GradientAppBar, StatusBadge, ActionCard, etc.)
├── theme/            # sistema de diseño (AppColors, AppTextStyles, AppTheme)
├── services/         # HTTP service singleton
└── config/           # API config

car_wash_backend/
├── controllers/      # lógica de negocio (auth, cars, payments)
├── middlewares/      # auth, validación, sanitize, rate limit, error handler
├── models/           # esquemas MongoDB (User, Car, Payment)
├── routes/           # definición de rutas REST
├── utils/            # logger (Winston), AppError, requestId
├── scripts/          # seedAdmin.js
├── __tests__/        # 49 tests con Jest (~85% cobertura)
└── admin-panel/      # panel web HTML con login JWT
```

## Licencia

© 2024 Carlos Z. Todos los derechos reservados.
