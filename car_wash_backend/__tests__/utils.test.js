require('./helpers/setup');
const { AppError, NotFoundError, ValidationError, UnauthorizedError, ForbiddenError } = require('../utils/AppError');

describe('AppError', () => {
  test('creates error with correct status and code', () => {
    const err = new AppError('Test error', 400, 'TEST_CODE');
    expect(err.message).toBe('Test error');
    expect(err.statusCode).toBe(400);
    expect(err.code).toBe('TEST_CODE');
    expect(err.isOperational).toBe(true);
  });
});

describe('NotFoundError', () => {
  test('creates 404 error with resource name', () => {
    const err = new NotFoundError('Usuario');
    expect(err.message).toBe('Usuario no encontrado');
    expect(err.statusCode).toBe(404);
    expect(err.code).toBe('NOT_FOUND');
  });
});

describe('ValidationError', () => {
  test('creates 400 error with details', () => {
    const details = [{ field: 'email', message: 'Email inválido' }];
    const err = new ValidationError('Datos inválidos', details);
    expect(err.message).toBe('Datos inválidos');
    expect(err.statusCode).toBe(400);
    expect(err.details).toEqual(details);
  });
});

describe('UnauthorizedError', () => {
  test('creates 401 error', () => {
    const err = new UnauthorizedError();
    expect(err.message).toBe('No autorizado');
    expect(err.statusCode).toBe(401);
  });
});

describe('ForbiddenError', () => {
  test('creates 403 error', () => {
    const err = new ForbiddenError();
    expect(err.message).toBe('Acceso denegado');
    expect(err.statusCode).toBe(403);
  });
});
