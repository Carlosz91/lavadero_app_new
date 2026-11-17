const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const User = require('../models/userModel');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/car_wash';

async function seedAdmin() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Conectado a MongoDB');

    // Credenciales por argumentos o variables de entorno; sin contraseña por defecto.
    const email = process.argv[2] || process.env.ADMIN_EMAIL;
    const password = process.argv[3] || process.env.ADMIN_PASSWORD;
    const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
    if (!email || !password) {
      throw new Error(
        'Uso: npm run create-admin -- <email> <password>  (o ADMIN_EMAIL / ADMIN_PASSWORD)'
      );
    }
    if (!PASSWORD_REGEX.test(password)) {
      throw new Error(
        'La contraseña debe tener 8+ caracteres, mayúscula, minúscula, número y símbolo (@$!%*?&)'
      );
    }

    const existing = await User.findOne({ email });
    if (existing) {
      console.log(`El usuario ${email} ya existe. Actualizando a admin...`);
      existing.role = 'admin';
      await existing.save();
      console.log(`Usuario ${email} actualizado a admin`);
    } else {
      const admin = new User({
        email,
        password,
        name: 'Administrador',
        role: 'admin',
      });
      await admin.save();
      console.log(`Admin creado: ${email}`);
    }

    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

seedAdmin();
