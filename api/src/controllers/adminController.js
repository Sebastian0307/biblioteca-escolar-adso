const xlsx = require('xlsx');
const bcrypt = require('bcryptjs');
const { Usuario, Login } = require('../models');

const cargarUsuariosExcel = async (req, res) => {
  try {
    const archivo = req.file || (req.files && req.files[0]);

    if (!archivo) {
      return res.status(400).json({
        ok: false,
        mensaje: 'No se adjuntó ningún archivo Excel (use el campo "archivo").'
      });
    }

    const workbook = xlsx.read(archivo.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const filas = xlsx.utils.sheet_to_json(worksheet, { defval: '' });

    if (!filas || filas.length === 0) {
      return res.status(400).json({
        ok: false,
        mensaje: 'El archivo Excel está vacío o no tiene filas válidas.'
      });
    }

    let creados = 0;
    let actualizados = 0;
    const errores = [];

    for (let i = 0; i < filas.length; i++) {
      const fila = filas[i];
      const normalizado = {};
      Object.keys(fila).forEach((k) => {
        normalizado[k.trim().toLowerCase()] = fila[k];
      });

      const nombre = String(normalizado.nombre || normalizado.nombres || '').trim();
      const apellido = String(normalizado.apellido || normalizado.apellidos || '').trim();
      const documento = String(normalizado.documento || normalizado.cedula || normalizado.identificacion || '').trim();
      let tipo_usuario = String(normalizado.tipo_usuario || normalizado.rol || normalizado.tipo || 'estudiante')
        .trim()
        .toLowerCase();

      if (!['estudiante', 'profesor', 'administrador'].includes(tipo_usuario)) {
        tipo_usuario = 'estudiante';
      }

      if (!nombre || !apellido || !documento) {
        errores.push({
          fila: i + 2,
          motivo: 'Faltan campos obligatorios (nombre, apellido o documento)'
        });
        continue;
      }

      let usuario = await Usuario.findOne({ where: { documento } });
      const hashPassword = await bcrypt.hash(documento, 10);

      if (!usuario) {
        usuario = await Usuario.create({
          nombre,
          apellido,
          documento,
          tipo_usuario
        });

        await Login.create({
          id_usuario: usuario.id_usuario,
          documento,
          contrasena: hashPassword
        });
        creados++;
      } else {
        usuario.nombre = nombre;
        usuario.apellido = apellido;
        usuario.tipo_usuario = tipo_usuario;
        await usuario.save();

        const registroLogin = await Login.findOne({ where: { id_usuario: usuario.id_usuario } });
        if (registroLogin) {
          registroLogin.documento = documento;
          registroLogin.contrasena = hashPassword;
          await registroLogin.save();
        } else {
          await Login.create({
            id_usuario: usuario.id_usuario,
            documento,
            contrasena: hashPassword
          });
        }
        actualizados++;
      }
    }

    return res.json({
      ok: true,
      mensaje: `Carga masiva completada: ${creados} usuarios nuevos, ${actualizados} actualizados.`,
      resumen: {
        total_procesados: filas.length,
        creados,
        actualizados,
        errores
      }
    });
  } catch (error) {
    console.error('Error al procesar Excel:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al procesar el archivo Excel.',
      error: error.message
    });
  }
};

const listarUsuarios = async (req, res) => {
  try {
    const usuarios = await Usuario.findAll({
      order: [['id_usuario', 'ASC']]
    });
    return res.json(usuarios);
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al listar usuarios.',
      error: error.message
    });
  }
};

const descargarPlantillaExcel = (req, res) => {
  const datosEjemplo = [
    { nombre: 'Daniela', apellido: 'Vargas', documento: '40004001', tipo_usuario: 'estudiante' },
    { nombre: 'Alejandro', apellido: 'Castro', documento: '40004002', tipo_usuario: 'estudiante' },
    { nombre: 'Ricardo', apellido: 'Mendoza', documento: '50005001', tipo_usuario: 'profesor' }
  ];

  const wb = xlsx.utils.book_new();
  const ws = xlsx.utils.json_to_sheet(datosEjemplo);
  xlsx.utils.book_append_sheet(wb, ws, 'Usuarios');

  const buffer = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
  res.setHeader('Content-Disposition', 'attachment; filename="plantilla_usuarios_biblioteca.xlsx"');
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  return res.send(buffer);
};

const crearUsuario = async (req, res) => {
  try {
    const { nombre, apellido, documento, tipo_usuario = 'profesor', contrasena } = req.body;

    if (!nombre || !apellido || !documento) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Los campos nombre, apellido y documento son obligatorios.'
      });
    }

    const existente = await Usuario.findOne({ where: { documento: String(documento).trim() } });
    if (existente) {
      return res.status(400).json({
        ok: false,
        mensaje: `El documento ${documento} ya se encuentra registrado.`
      });
    }

    const nuevoUsuario = await Usuario.create({
      nombre: nombre.trim(),
      apellido: apellido.trim(),
      documento: String(documento).trim(),
      tipo_usuario
    });

    const passInicial = contrasena ? String(contrasena).trim() : String(documento).trim();
    const hash = await bcrypt.hash(passInicial, 10);

    await Login.create({
      id_usuario: nuevoUsuario.id_usuario,
      documento: nuevoUsuario.documento,
      contrasena: hash
    });

    return res.status(201).json({
      ok: true,
      mensaje: `Usuario (${tipo_usuario}) creado exitosamente con contraseña encriptada.`,
      usuario: nuevoUsuario
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al crear el usuario.',
      error: error.message
    });
  }
};

const actualizarUsuario = async (req, res) => {
  try {
    const { id } = req.params;
    const { nombre, apellido, tipo_usuario } = req.body;

    const usuario = await Usuario.findByPk(id);
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Usuario no encontrado.'
      });
    }

    if (nombre) usuario.nombre = nombre.trim();
    if (apellido) usuario.apellido = apellido.trim();
    if (tipo_usuario) usuario.tipo_usuario = tipo_usuario;
    await usuario.save();

    return res.json({
      ok: true,
      mensaje: 'Usuario actualizado exitosamente.',
      usuario
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al actualizar el usuario.',
      error: error.message
    });
  }
};

const eliminarUsuario = async (req, res) => {
  try {
    const { id } = req.params;
    const usuario = await Usuario.findByPk(id);
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Usuario no encontrado.'
      });
    }

    await usuario.destroy();
    return res.json({
      ok: true,
      mensaje: 'Usuario eliminado correctamente.'
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al eliminar usuario.',
      error: error.message
    });
  }
};

module.exports = {
  cargarUsuariosExcel,
  listarUsuarios,
  crearUsuario,
  actualizarUsuario,
  eliminarUsuario,
  descargarPlantillaExcel
};
