const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Usuario, Login, Libro, Ejemplar, Solicitud, Prestamo, Devolucion } = require('../models');
require('dotenv').config();

const ejecutarSeedDatos = async () => {
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

  // 5. Buscar o crear los registros en la tabla login asociando id_usuario y contraseña encriptada
  const [loginAdmin, adminLoginCreado] = await Login.findOrCreate({
    where: { id_usuario: admin.id_usuario },
    defaults: {
      id_usuario: admin.id_usuario,
      documento: '10001001',
      contrasena: hashAdmin
    }
  });
  if (!adminLoginCreado) {
    loginAdmin.documento = '10001001';
    loginAdmin.contrasena = hashAdmin;
    await loginAdmin.save();
  }

  const [loginEstudiante, estLoginCreado] = await Login.findOrCreate({
    where: { id_usuario: estudiante.id_usuario },
    defaults: {
      id_usuario: estudiante.id_usuario,
      documento: '30003001',
      contrasena: hashEstudiante
    }
  });
  if (!estLoginCreado) {
    loginEstudiante.documento = '30003001';
    loginEstudiante.contrasena = hashEstudiante;
    await loginEstudiante.save();
  }

  const [loginProfesor, profLoginCreado] = await Login.findOrCreate({
    where: { id_usuario: profesor.id_usuario },
    defaults: {
      id_usuario: profesor.id_usuario,
      documento: '20002001',
      contrasena: hashProfesor
    }
  });
  if (!profLoginCreado) {
    loginProfesor.documento = '20002001';
    loginProfesor.contrasena = hashProfesor;
    await loginProfesor.save();
  }

  return {
    admin_id: admin.id_usuario,
    estudiante_id: estudiante.id_usuario,
    profesor_id: profesor.id_usuario
  };
};

const login = async (req, res) => {
  try {
    const documento = String(req.body.documento || '').trim();
    const contrasena = String(req.body.contrasena || req.body.password || '').trim();

    if (!documento || !contrasena) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Debe proporcionar documento y contraseña.'
      });
    }

    const usuario = await Usuario.findOne({ where: { documento } });
    if (!usuario) {
      return res.status(401).json({
        ok: false,
        mensaje: 'Credenciales incorrectas. Usuario no encontrado.'
      });
    }

    let registroLogin = await Login.findOne({ where: { id_usuario: usuario.id_usuario } });

    // Si no existe registro en login pero sí en usuarios con clave igual al documento, permite ingreso inicial y crea el hash
    if (!registroLogin) {
      if (contrasena === usuario.documento) {
        const hash = await bcrypt.hash(contrasena, 10);
        registroLogin = await Login.create({
          id_usuario: usuario.id_usuario,
          documento: usuario.documento,
          contrasena: hash
        });
      } else {
        return res.status(401).json({
          ok: false,
          mensaje: 'Contraseña incorrecta.'
        });
      }
    } else {
      let passwordValida = false;
      const storedPass = registroLogin.contrasena;

      if (storedPass.startsWith('$2a$') || storedPass.startsWith('$2b$')) {
        passwordValida = await bcrypt.compare(contrasena, storedPass);
      } else {
        // Si en la BD se insertó en texto plano desde SQL, comparar y encriptar automáticamente
        if (contrasena === storedPass) {
          passwordValida = true;
          registroLogin.contrasena = await bcrypt.hash(contrasena, 10);
          await registroLogin.save();
        }
      }

      if (!passwordValida) {
        return res.status(401).json({
          ok: false,
          mensaje: 'Contraseña incorrecta.'
        });
      }
    }

    const rolLegible =
      usuario.tipo_usuario === 'administrador' || usuario.tipo_usuario === 'administrativo'
        ? 'Admin'
        : usuario.tipo_usuario === 'profesor'
          ? 'Profesor'
          : 'Estudiante';

    const payload = {
      id_usuario: usuario.id_usuario,
      nombre: usuario.nombre,
      apellido: usuario.apellido,
      documento: usuario.documento,
      tipo_usuario: usuario.tipo_usuario,
      rol: rolLegible
    };

    const token = jwt.sign(
      payload,
      process.env.JWT_SECRET || 'secreto_super_seguro_sena_2026',
      { expiresIn: '24h' }
    );

    return res.json({
      ok: true,
      mensaje: `Bienvenido(a) ${usuario.nombre} ${usuario.apellido}`,
      token,
      usuario: payload
    });
  } catch (error) {
    console.error('Error en login:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error interno al iniciar sesión.',
      error: error.message
    });
  }
};

const seed = async (req, res) => {
  try {
    await ejecutarSeedDatos();
    return res.status(200).json({
      mensaje: 'Usuarios semilla creados exitosamente'
    });
  } catch (error) {
    console.error('Error en seed:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al inicializar los usuarios semilla.',
      error: error.message
    });
  }
};

const perfil = async (req, res) => {
  try {
    const usuario = await Usuario.findByPk(req.usuario.id_usuario);
    return res.json({
      ok: true,
      usuario
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al obtener perfil.',
      error: error.message
    });
  }
};

const cambiarContrasena = async (req, res) => {
  try {
    const id_usuario = req.usuario ? req.usuario.id_usuario : req.body.id_usuario;
    const { contrasena_actual, nueva_contrasena } = req.body;

    if (!nueva_contrasena || String(nueva_contrasena).trim().length < 4) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Debe proporcionar una nueva contraseña válida (mínimo 4 caracteres).'
      });
    }

    const usuario = await Usuario.findByPk(id_usuario);
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Usuario no encontrado.'
      });
    }

    // Criterio Historia 1 del documento SENA: el sistema rechaza usar el documento como nueva contraseña
    if (String(nueva_contrasena).trim() === String(usuario.documento).trim()) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Por seguridad, la nueva contraseña no puede ser igual a tu número de documento.'
      });
    }

    let registroLogin = await Login.findOne({ where: { id_usuario: usuario.id_usuario } });

    if (registroLogin && contrasena_actual) {
      const esHash = registroLogin.contrasena.startsWith('$2a$') || registroLogin.contrasena.startsWith('$2b$');
      const coincide = esHash
        ? await bcrypt.compare(String(contrasena_actual).trim(), registroLogin.contrasena)
        : String(contrasena_actual).trim() === registroLogin.contrasena;

      if (!coincide) {
        return res.status(401).json({
          ok: false,
          mensaje: 'La contraseña actual ingresada es incorrecta.'
        });
      }
    }

    const nuevoHash = await bcrypt.hash(String(nueva_contrasena).trim(), 10);

    if (!registroLogin) {
      await Login.create({
        id_usuario: usuario.id_usuario,
        documento: usuario.documento,
        contrasena: nuevoHash
      });
    } else {
      registroLogin.contrasena = nuevoHash;
      await registroLogin.save();
    }

    return res.json({
      ok: true,
      mensaje: 'Contraseña actualizada exitosamente.'
    });
  } catch (error) {
    console.error('Error al cambiar contraseña:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al cambiar la contraseña.',
      error: error.message
    });
  }
};

const register = async (req, res) => {
  try {
    const documento = String(req.body.documento || '').trim();
    const nombreCompleto = String(req.body.nombre || '').trim();
    const apellidoReq = req.body.apellido ? String(req.body.apellido).trim() : '';
    const contrasena = String(req.body.contrasena || req.body.password || '').trim();
    const rolEntrada = String(req.body.rol || req.body.tipo_usuario || 'Estudiante').trim();

    if (!documento || !nombreCompleto || !contrasena) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Todos los campos (documento, nombre, contraseña y rol) son obligatorios.'
      });
    }

    const existente = await Usuario.findOne({ where: { documento } });
    if (existente) {
      return res.status(400).json({
        ok: false,
        mensaje: `El documento ${documento} ya se encuentra registrado.`
      });
    }

    // Separar nombre y apellido si se envió en un solo campo "nombre"
    let nombre = nombreCompleto;
    let apellido = apellidoReq;
    if (!apellido) {
      const partes = nombreCompleto.split(/\s+/);
      if (partes.length > 1) {
        nombre = partes[0];
        apellido = partes.slice(1).join(' ');
      } else {
        apellido = '';
      }
    }

    // Normalizar rol a los valores de base de datos ('administrador', 'profesor', 'estudiante')
    const rolLower = rolEntrada.toLowerCase();
    let tipo_usuario = 'estudiante';
    if (rolLower === 'admin' || rolLower === 'administrador' || rolLower === 'administrativo') {
      tipo_usuario = 'administrador';
    } else if (rolLower === 'profesor' || rolLower === 'docente') {
      tipo_usuario = 'profesor';
    }

    const rolLegible =
      tipo_usuario === 'administrador'
        ? 'Admin'
        : tipo_usuario === 'profesor'
          ? 'Profesor'
          : 'Estudiante';

    // 1. Crear registro en la tabla usuarios en Supabase
    const nuevoUsuario = await Usuario.create({
      nombre,
      apellido,
      documento,
      tipo_usuario
    });

    // 2. Encriptar contraseña con bcrypt y guardar en la tabla login
    const hashPassword = await bcrypt.hash(contrasena, 10);
    await Login.create({
      id_usuario: nuevoUsuario.id_usuario,
      documento: nuevoUsuario.documento,
      contrasena: hashPassword
    });

    const payload = {
      id_usuario: nuevoUsuario.id_usuario,
      nombre: nuevoUsuario.nombre,
      apellido: nuevoUsuario.apellido,
      documento: nuevoUsuario.documento,
      tipo_usuario: nuevoUsuario.tipo_usuario,
      rol: rolLegible
    };

    const token = jwt.sign(
      payload,
      process.env.JWT_SECRET || 'secreto_super_seguro_sena_2026',
      { expiresIn: '24h' }
    );

    return res.status(201).json({
      ok: true,
      mensaje: 'Usuario registrado exitosamente.',
      token,
      usuario: payload
    });
  } catch (error) {
    console.error('Error en registro:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error interno al registrar el usuario.',
      error: error.message
    });
  }
};

module.exports = {
  login,
  register,
  seed,
  perfil,
  cambiarContrasena,
  ejecutarSeedDatos
};
