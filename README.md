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

- **Registro de vehículos** — cualquier usuario autenticado puede registrar un auto
- **Agendamiento** — selección de fecha y hora al registrar el vehículo
- **Estado del lavado** — seguimiento en tiempo real con filtros por estado
- **Gestión de pagos** — registro y consulta de pagos
- **Panel admin** — `http://localhost:5000/admin/` (solo admin/staff)
- **Roles** — `admin`/`staff` pueden cambiar estados; `user` solo registra y agenda
- **Primer usuario** registrado se convierte en `admin` automáticamente
- **Notificaciones push**, autenticación biométrica, modo oscuro
- **API REST** documentada con Swagger en `http://localhost:5000/api-docs`

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
├── screens/          # 9 pantallas
├── widgets/          # componentes reutilizables
├── theme/            # sistema de diseño
├── services/         # HTTP service
└── config/           # API config

car_wash_backend/
├── controllers/      # lógica de negocio
├── middlewares/      # auth, validación, sanitize, rate limit
├── models/           # esquemas MongoDB
├── routes/           # definición de rutas
├── utils/            # logger, AppError, etc.
├── __tests__/        # tests Jest
└── admin-panel/      # panel web HTML
```

## Licencia

© 2024 Carlos Z. Todos los derechos reservados.
