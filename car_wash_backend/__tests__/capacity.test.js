require('./helpers/setup');
const request = require('supertest');
const app = require('../server');
const Car = require('../models/carModel');
const DayCapacity = require('../models/dayCapacityModel');
const { dayKey, MAX_PER_DAY } = require('../services/capacityService');

const DATE = '2030-06-15';
let n = 0;

const newUser = async () => {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ name: 'Cap User', email: `cap_${Date.now()}_${n++}@test.com`, password: 'TestPass1!' });
  return { token: res.body.token, userId: res.body.userId };
};

const registerCar = (token, scheduledDate = DATE) =>
  request(app)
    .post('/api/cars/registercar')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', `cap-${Date.now()}-${Math.random()}`)
    .send({
      plate: `CAP-${n++}`,
      brand: 'Honda',
      model: 'Civic',
      washType: 'Básico',
      scheduledDate,
    });

describe('capacidad diaria', () => {
  test('dayKey: fecha sin hora es el día; con hora usa la zona del negocio', () => {
    expect(dayKey('2030-06-15')).toBe('2030-06-15');
    // 02:00 UTC del 16 = 23:00 del 15 en Asunción (UTC-3)
    expect(dayKey('2030-06-16T02:00:00.000Z')).toBe('2030-06-15');
    expect(dayKey('basura')).toBeNull();
  });

  test('requests simultáneos nunca superan el cupo diario', async () => {
    const users = await Promise.all(Array.from({ length: 9 }, newUser));
    const results = await Promise.all(users.map((u) => registerCar(u.token)));

    const ok = results.filter((r) => r.status === 201).length;
    const full = results.filter((r) => r.status === 400).length;
    expect(ok).toBe(MAX_PER_DAY);
    expect(full).toBe(users.length - MAX_PER_DAY);
    expect(await Car.countDocuments({ capacityKey: DATE })).toBe(MAX_PER_DAY);
    expect((await DayCapacity.findOne({ date: DATE })).count).toBe(MAX_PER_DAY);
  });

  test('cancelar un auto libera su cupo', async () => {
    const admin = await newUser(); // primer usuario = admin
    const users = await Promise.all(Array.from({ length: MAX_PER_DAY }, newUser));
    const created = [];
    for (const u of users) created.push(await registerCar(u.token).expect(201));

    const extra = await newUser();
    await registerCar(extra.token).expect(400); // lleno

    const carId = created[0].body.car._id;
    await request(app)
      .put(`/api/cars/update-status/${carId}`)
      .set('Authorization', `Bearer ${admin.token}`)
      .send({ status: 'Cancelado' })
      .expect(200);

    await registerCar(extra.token).expect(201); // ahora hay lugar
  });

  test('disponibilidad refleja los cupos usados', async () => {
    const [a, b] = await Promise.all([newUser(), newUser()]);
    await registerCar(a.token).expect(201);
    await registerCar(b.token).expect(201);
    const res = await request(app)
      .get(`/api/cars/availability?date=${DATE}`)
      .set('Authorization', `Bearer ${a.token}`)
      .expect(200);
    expect(res.body).toMatchObject({
      booked: 2,
      available: MAX_PER_DAY - 2,
      maxPerDay: MAX_PER_DAY,
    });
  });

  test('migra perezosamente autos agendados antes del contador', async () => {
    const u = await newUser();
    // autos "legacy" (sin capacityKey ni contador) en esa fecha, a un cupo de llenarse
    await Car.insertMany(
      Array.from({ length: MAX_PER_DAY - 1 }, (_, i) => ({
        userId: u.userId,
        plate: `OLD-${i}`,
        brand: 'X',
        model: 'Y',
        washType: 'Básico',
        amount: 1,
        scheduledDate: new Date(`${DATE}T12:00:00.000Z`),
      }))
    );
    const [a, b] = await Promise.all([newUser(), newUser()]);
    const r = await Promise.all([registerCar(a.token), registerCar(b.token)]);
    expect(r.filter((x) => x.status === 201)).toHaveLength(1); // solo queda 1 cupo
  });

  test('rechaza una fecha inválida', async () => {
    const u = await newUser();
    await registerCar(u.token, 'no-es-fecha').expect(400);
  });

  test('si falla el guardado, el cupo se libera', async () => {
    const u = await newUser();
    const spy = jest.spyOn(Car.prototype, 'save').mockRejectedValueOnce(new Error('db caída'));
    await registerCar(u.token).expect(500);
    spy.mockRestore();
    expect((await DayCapacity.findOne({ date: DATE })).count).toBe(0);
  });
});
