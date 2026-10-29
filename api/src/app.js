const express = require('express');
const cors = require('cors');
const path = require('path');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const { sequelize } = require('./models');
const Usuario = require('./models/usuario');
const Login = require('./models/login');
const authRoutes = require('./routes/authRoutes');
const libroRoutes = require('./routes/libroRoutes');
const solicitudRoutes = require('./routes/solicitudRoutes');
const adminRoutes = require('./routes/adminRoutes');
const prestamoRoutes = require('./routes/prestamoRoutes');
const solicitudController = require('./controllers/solicitudController');
const { verificarToken } = require('./middlewares/authMiddleware');
const { ejecutarSeedDatos } = require('./controllers/authController');

const app = express();
const PORT = process.env.PORT || 3000;

// Middlewares globales (Configuración explícita de CORS para Flutter Web y móvil)
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.options('*', cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servir el Simulador Móvil Instantáneo estático en /public
app.use(express.static(path.join(__dirname, '../public')));

// Endpoint POST /seed para crear usuarios semilla con contraseñas encriptadas en bcrypt
app.post('/seed', async (req, res) => {
  try {
    // 1. Buscar o crear al administrador: Carlos Ramírez (10001001)
    const [admin] = await Usuario.findOrCreate({
      where: { documento: '10001001' },
      defaults: {
        nombre: 'Carlos',
        apellido: 'Ramírez',
        documento: '10001001',
        tipo_usuario: 'administrador'
      }
    });

    // 2. Buscar o crear a la estudiante: Valentina López (30003001)
    const [estudiante] = await Usuario.findOrCreate({
      where: { documento: '30003001' },
      defaults: {
        nombre: 'Valentina',
        apellido: 'López',
        documento: '30003001',
        tipo_usuario: 'estudiante'
      }
    });

    // 3. Buscar o crear al profesor: Andrés Martínez (20002001)
    const [profesor] = await Usuario.findOrCreate({
      where: { documento: '20002001' },
      defaults: {
        nombre: 'Andrés',
        apellido: 'Martínez',
        documento: '20002001',
        tipo_usuario: 'profesor'
      }
    });

    // 4. Encriptar las contraseñas ('10001001', '30003001' y '20002001') usando bcrypt
    const hashAdmin = await bcrypt.hash('10001001', 10);
    const hashEstudiante = await bcrypt.hash('30003001', 10);
    const hashProfesor = await bcrypt.hash('20002001', 10);

    // 5. Buscar o crear los registros en la tabla login asociando el id_usuario correcto y la contraseña encriptada
    const [loginAdmin, creadoAdmin] = await Login.findOrCreate({
      where: { id_usuario: admin.id_usuario },
      defaults: {
        id_usuario: admin.id_usuario,
        documento: '10001001',
        contrasena: hashAdmin
      }
    });
    if (!creadoAdmin) {
      loginAdmin.documento = '10001001';
      loginAdmin.contrasena = hashAdmin;
      await loginAdmin.save();
    }

    const [loginEstudiante, creadoEstudiante] = await Login.findOrCreate({
      where: { id_usuario: estudiante.id_usuario },
      defaults: {
        id_usuario: estudiante.id_usuario,
        documento: '30003001',
        contrasena: hashEstudiante
      }
    });
    if (!creadoEstudiante) {
      loginEstudiante.documento = '30003001';
      loginEstudiante.contrasena = hashEstudiante;
      await loginEstudiante.save();
    }

    const [loginProfesor, creadoProfesor] = await Login.findOrCreate({
      where: { id_usuario: profesor.id_usuario },
      defaults: {
        id_usuario: profesor.id_usuario,
        documento: '20002001',
        contrasena: hashProfesor
      }
    });
    if (!creadoProfesor) {
      loginProfesor.documento = '20002001';
      loginProfesor.contrasena = hashProfesor;
      await loginProfesor.save();
    }

    // 5. Retornar respuesta 200 exacta
    return res.status(200).json({ mensaje: 'Usuarios semilla creados exitosamente' });
  } catch (error) {
    console.error('Error en POST /seed:', error);
    return res.status(500).json({
      mensaje: 'Error al crear usuarios semilla',
      error: error.message
    });
  }
});

// Rutas principales
app.use('/auth', authRoutes);
app.use('/libros', libroRoutes);
app.use('/solicitudes', solicitudRoutes);
app.use('/gestor/solicitudes', solicitudRoutes);
app.use('/admin', adminRoutes);

// Flujo de préstamos (solicitar -> pendiente -> aprobar)
app.use('/prestamos', prestamoRoutes);

// Rutas directas del resumen de la guía SENA (página 5)
app.get('/mis-prestamos', verificarToken, solicitudController.misPrestamos);
app.get('/mis-solicitudes', verificarToken, solicitudController.misSolicitudes);

// Alias con prefijo /api por compatibilidad adicional
app.use('/api/auth', authRoutes);
app.use('/api/libros', libroRoutes);
app.use('/api/prestamos', prestamoRoutes);
app.use('/api/solicitudes', solicitudRoutes);
app.use('/api/gestor/solicitudes', solicitudRoutes);
app.use('/api/admin', adminRoutes);

// Endpoint de estado de salud de la API
app.get('/api/status', (req, res) => {
  res.json({
    ok: true,
    sistema: 'API Biblioteca Escolar - SENA 2026',
    estado: 'En línea',
    timestamp: new Date().toISOString()
  });
});

// Ruta raíz sirve el simulador móvil interactivo
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

// Inicialización de base de datos en Supabase y arranque del servidor
const iniciarServidor = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Conexión exitosa a PostgreSQL en Supabase.');

    await sequelize.sync();
    console.log('✅ Modelos sincronizados correctamente con Supabase.');

    const resumen = await ejecutarSeedDatos();
    console.log('📚 Estado inicial de la Base de Datos:', resumen);

    app.listen(PORT, () => {
      console.log(`🚀 Servidor ejecutándose en http://localhost:${PORT}`);
      console.log(`📱 Simulador Móvil Web disponible en http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error('❌ Error al conectar o sincronizar con la base de datos:', error.message);
    app.listen(PORT, () => {
      console.log(`⚠️ Servidor iniciado en modo espera en http://localhost:${PORT}`);
    });
  }
};

iniciarServidor();

module.exports = app;
