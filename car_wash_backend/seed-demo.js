const mongoose = require('mongoose');
require('dotenv').config();

const User = require('./models/userModel');
const Car = require('./models/carModel');
const Payment = require('./models/paymentModel');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/car_wash';

const users = [
  { email: 'carlos@email.com', password: 'Demo1234@', name: 'Carlos Pérez' },
  { email: 'maria@email.com', password: 'Demo1234@', name: 'María López' },
  { email: 'juan@email.com', password: 'Demo1234@', name: 'Juan González' },
];

const cars = [
  { plate: 'ABC-123', model: 'Corolla', brand: 'Toyota', washType: 'Completo', amount: 80000, status: 'Completado' },
  { plate: 'XYZ-789', model: 'Civic', brand: 'Honda', washType: 'Premium', amount: 120000, status: 'En Progreso' },
  { plate: 'DEF-456', model: 'Onix', brand: 'Chevrolet', washType: 'Básico', amount: 40000, status: 'Pendiente' },
  { plate: 'GHI-789', model: 'Focus', brand: 'Ford', washType: 'Completo', amount: 75000, status: 'Completado' },
  { plate: 'JKL-012', model: 'March', brand: 'Nissan', washType: 'Básico', amount: 35000, status: 'Pendiente' },
  { plate: 'MNO-345', model: 'Tucson', brand: 'Hyundai', washType: 'Detailing', amount: 200000, status: 'Completado' },
  { plate: 'PQR-678', model: 'CX-5', brand: 'Mazda', washType: 'Premium', amount: 130000, status: 'En Progreso' },
  { plate: 'STU-901', model: 'Kicks', brand: 'Nissan', washType: 'Completo', amount: 85000, status: 'Pendiente' },
  { plate: 'VWX-234', model: 'Hilux', brand: 'Toyota', washType: 'Premium', amount: 150000, status: 'Completado' },
  { plate: 'YZA-567', model: 'X1', brand: 'BMW', washType: 'Detailing', amount: 250000, status: 'Completado' },
];

const methods = ['Efectivo', 'Tarjeta', 'Transferencia', 'Mercado Pago'];

async function seed() {
  await mongoose.connect(MONGO_URI);
  console.log('Conectado a MongoDB');

  await User.deleteMany({});
  await Car.deleteMany({});
  await Payment.deleteMany({});

  const createdUsers = [];
  for (const u of users) {
    const user = await User.create(u);
    createdUsers.push(user);
    console.log(`Usuario: ${user.email} (${user._id})`);
  }

  const createdCars = [];
  for (let i = 0; i < cars.length; i++) {
    const c = cars[i];
    const user = createdUsers[i % createdUsers.length];
    const daysAgo = Math.floor(Math.random() * 14);
    const createdAt = new Date(Date.now() - daysAgo * 86400000);
    const car = await Car.create({
      userId: user._id,
      plate: c.plate,
      model: c.model,
      brand: c.brand,
      washType: c.washType,
      amount: c.amount,
      status: c.status,
      createdAt,
    });
    createdCars.push(car);
    console.log(`  Auto: ${car.plate} - ${car.status}`);
  }

  for (let i = 0; i < 8; i++) {
    const car = createdCars[i % createdCars.length];
    const payment = await Payment.create({
      userId: car.userId,
      plate: car.plate,
      method: methods[i % methods.length],
      amount: car.amount,
      status: car.status === 'Completado' ? 'Pagado' : 'Pendiente',
      carId: car._id,
      date: car.createdAt,
    });
    console.log(`  Pago: ${payment.plate} - ${payment.status} (Gs. ${payment.amount})`);
  }

  console.log('\n✅ Seed completado');
  console.log(`   ${createdUsers.length} usuarios`);
  console.log(`   ${createdCars.length} vehículos`);
  console.log(`   8 pagos`);
  console.log('\nAdmin existente: admin@admin.com / la contraseña que configuraste');

  await mongoose.disconnect();
}

seed().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
