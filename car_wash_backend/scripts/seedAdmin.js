const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const User = require('../models/userModel');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/carwash';

async function seedAdmin() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Conectado a MongoDB');

    const email = process.argv[2] || 'admin@carwash.com';
    const password = process.argv[3] || 'Admin123!';

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
