const swaggerJSDoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Car Wash API',
      version: '2.0.0',
      description: 'API para sistema de lavado de vehículos',
      contact: {
        name: 'Desarrollador',
      },
    },
    servers: [
      { url: 'http://localhost:5000', description: 'Desarrollo' },
      { url: 'https://lavaderoappnew-production.up.railway.app', description: 'Producción' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            id: { type: 'string', example: '60d5f484f1a2c8b1f8e4e1a1' },
            email: { type: 'string', example: 'usuario@example.com' },
            name: { type: 'string', example: 'Juan Pérez' },
            role: { type: 'string', enum: ['user', 'admin', 'staff'] },
          },
        },
        Car: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            plate: { type: 'string', example: 'ABC-1234' },
            model: { type: 'string', example: 'Corolla' },
            brand: { type: 'string', example: 'Toyota' },
            washType: { type: 'string', enum: ['Básico', 'Premium', 'Completo', 'Detailing'] },
            amount: { type: 'number', example: 150.00 },
            status: { type: 'string', enum: ['Pendiente', 'En Progreso', 'Completado', 'Cancelado'] },
            userId: { type: 'string' },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
          },
        },
        Payment: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            userId: { type: 'string' },
            plate: { type: 'string', example: 'ABC-1234' },
            method: { type: 'string', enum: ['Efectivo', 'Tarjeta', 'Transferencia', 'Otro'] },
            amount: { type: 'number', example: 150.00 },
            status: { type: 'string', enum: ['Pendiente', 'Pagado', 'Cancelado', 'Reembolsado'] },
            date: { type: 'string', format: 'date-time' },
            carId: { type: 'string', nullable: true },
          },
        },
        Error: {
          type: 'object',
          properties: {
            error: { type: 'string', example: 'Mensaje de error' },
            code: { type: 'string', example: 'VALIDATION_ERROR' },
            details: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  field: { type: 'string' },
                  message: { type: 'string' },
                },
              },
            },
          },
        },
        Pagination: {
          type: 'object',
          properties: {
            page: { type: 'integer', example: 1 },
            limit: { type: 'integer', example: 20 },
            total: { type: 'integer', example: 100 },
            pages: { type: 'integer', example: 5 },
          },
        },
        PaginatedCars: {
          type: 'object',
          properties: {
            data: { type: 'array', items: { $ref: '#/components/schemas/Car' } },
            pagination: { $ref: '#/components/schemas/Pagination' },
          },
        },
        PaginatedPayments: {
          type: 'object',
          properties: {
            data: { type: 'array', items: { $ref: '#/components/schemas/Payment' } },
            pagination: { $ref: '#/components/schemas/Pagination' },
          },
        },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: ['./routes/*.js', './adminRoutes.js'],
};

module.exports = swaggerJSDoc(options);
