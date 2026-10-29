const { Solicitud, Ejemplar, Libro, Usuario, Prestamo, Devolucion } = require('../models');

const crearSolicitud = async (req, res) => {
  try {
    const id_usuario = req.usuario ? req.usuario.id_usuario : req.body.id_usuario;
    let { id_ejemplar, id_libro } = req.body;

    if (!id_usuario) {
      return res.status(401).json({
        ok: false,
        mensaje: 'Usuario no autenticado para registrar el préstamo.'
      });
    }

    let ejemplar = null;

    // Validar stock buscando el ejemplar seleccionado o un ejemplar disponible del libro
    if (id_ejemplar) {
      ejemplar = await Ejemplar.findByPk(id_ejemplar, {
        include: [{ model: Libro, as: 'libro' }]
      });
    } else if (id_libro) {
      ejemplar = await Ejemplar.findOne({
        where: { id_libro, disponibilidad: 'disponible' },
        include: [{ model: Libro, as: 'libro' }]
      });
    }

    if (!ejemplar) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Sin stock disponible: no hay ejemplares disponibles para este libro.'
      });
    }

    if (ejemplar.disponibilidad !== 'disponible') {
      return res.status(400).json({
        ok: false,
        mensaje: `Sin stock disponible: el ejemplar ${ejemplar.codigo_inventario} ya se encuentra ${ejemplar.disponibilidad}.`
      });
    }

    // Evitar solicitudes pendientes duplicadas del mismo usuario para el mismo ejemplar
    const pendienteExistente = await Solicitud.findOne({
      where: { id_usuario, id_ejemplar: ejemplar.id_ejemplar, estado: 'pendiente' }
    });
    if (pendienteExistente) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Ya tienes una solicitud pendiente para este ejemplar.'
      });
    }

    // Registrar la solicitud de préstamo en estado 'pendiente'.
    // El ejemplar NO se descuenta del stock hasta que el administrador la apruebe.
    const nuevaSolicitud = await Solicitud.create({
      id_usuario,
      id_ejemplar: ejemplar.id_ejemplar,
      estado: 'pendiente'
    });

    const solicitudCompleta = await Solicitud.findByPk(nuevaSolicitud.id_solicitud, {
      include: [
        { model: Usuario, as: 'usuario' },
        {
          model: Ejemplar,
          as: 'ejemplar',
          include: [{ model: Libro, as: 'libro' }]
        }
      ]
    });

    return res.status(201).json({
      ok: true,
      mensaje: `Solicitud de préstamo enviada (Ejemplar ${ejemplar.codigo_inventario}). Pendiente de aprobación.`,
      solicitud: solicitudCompleta
    });
  } catch (error) {
    console.error('Error al registrar préstamo:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al registrar el préstamo.',
      error: error.message
    });
  }
};

const listarSolicitudes = async (req, res) => {
  try {
    const { estado } = req.query;
    const whereClause = estado ? { estado } : {};

    const solicitudes = await Solicitud.findAll({
      where: whereClause,
      include: [
        { model: Usuario, as: 'usuario' },
        {
          model: Ejemplar,
          as: 'ejemplar',
          include: [{ model: Libro, as: 'libro' }]
        }
      ],
      order: [['id_solicitud', 'DESC']]
    });

    return res.json(solicitudes);
  } catch (error) {
    console.error('Error al listar solicitudes:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al obtener las solicitudes.',
      error: error.message
    });
  }
};

const aprobarSolicitud = async (req, res) => {
  try {
    const { id } = req.params;

    let solicitud = await Solicitud.findByPk(id, {
      include: [
        { model: Usuario, as: 'usuario' },
        {
          model: Ejemplar,
          as: 'ejemplar',
          include: [{ model: Libro, as: 'libro' }]
        }
      ]
    });

    // Soporte adicional: si id corresponde a id_prestamo
    if (!solicitud) {
      const prestamoRef = await Prestamo.findByPk(id);
      if (prestamoRef) {
        solicitud = await Solicitud.findOne({
          where: {
            id_usuario: prestamoRef.id_usuario,
            id_ejemplar: prestamoRef.id_ejemplar
          },
          include: [
            { model: Usuario, as: 'usuario' },
            {
              model: Ejemplar,
              as: 'ejemplar',
              include: [{ model: Libro, as: 'libro' }]
            }
          ]
        });
      }
    }

    if (!solicitud) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Solicitud no encontrada.'
      });
    }

    if (solicitud.estado === 'aprobada') {
      return res.status(400).json({
        ok: false,
        mensaje: 'Esta solicitud ya fue aprobada anteriormente.'
      });
    }

    const ejemplar = solicitud.ejemplar;
    if (!ejemplar) {
      return res.status(404).json({
        ok: false,
        mensaje: 'El ejemplar asociado no existe.'
      });
    }

    if (ejemplar.disponibilidad !== 'disponible') {
      return res.status(400).json({
        ok: false,
        mensaje: `El ejemplar ${ejemplar.codigo_inventario} ya se encuentra ${ejemplar.disponibilidad}.`
      });
    }

    // 1. Marcar solicitud como aprobada
    solicitud.estado = 'aprobada';
    await solicitud.save();

    // 2. Cambiar disponibilidad del ejemplar a 'prestado'
    ejemplar.disponibilidad = 'prestado';
    await ejemplar.save();

    // 3. Crear el registro activo en prestamos
    const hoy = new Date().toISOString().split('T')[0];
    const nuevoPrestamo = await Prestamo.create({
      id_usuario: solicitud.id_usuario,
      id_libro: ejemplar.id_libro,
      id_ejemplar: ejemplar.id_ejemplar,
      fecha_prestamo: hoy,
      fecha_devolucion: null,
      estado: 'activo'
    });

    return res.json({
      ok: true,
      mensaje: `Préstamo aprobado con éxito. Estado actualizado a 'activo' (Ejemplar ${ejemplar.codigo_inventario}).`,
      solicitud,
      prestamo: nuevoPrestamo,
      estado: 'activo'
    });
  } catch (error) {
    console.error('Error al aprobar solicitud:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al aprobar la solicitud.',
      error: error.message
    });
  }
};

const rechazarSolicitud = async (req, res) => {
  try {
    const { id } = req.params;
    const solicitud = await Solicitud.findByPk(id);
    if (!solicitud) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Solicitud no encontrada.'
      });
    }

    solicitud.estado = 'rechazada';
    await solicitud.save();

    return res.json({
      ok: true,
      mensaje: 'Solicitud rechazada.',
      solicitud
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al rechazar la solicitud.',
      error: error.message
    });
  }
};

const registrarDevolucion = async (req, res) => {
  try {
    const { id } = req.params;
    const { observaciones = 'Entregado en buenas condiciones', condicion } = req.body;

    // Soporta tanto id_prestamo como id_solicitud para máxima compatibilidad
    let prestamo = await Prestamo.findOne({
      where: { id_prestamo: id, estado: 'activo' }
    });

    if (!prestamo) {
      const solicitud = await Solicitud.findByPk(id);
      if (solicitud) {
        prestamo = await Prestamo.findOne({
          where: {
            id_usuario: solicitud.id_usuario,
            id_ejemplar: solicitud.id_ejemplar,
            estado: 'activo'
          }
        });
      }
    }

    if (!prestamo) {
      prestamo = await Prestamo.findByPk(id);
    }

    if (!prestamo) {
      return res.status(404).json({
        ok: false,
        mensaje: 'No se encontró un préstamo activo correspondiente al ID indicado.'
      });
    }

    if (prestamo.estado === 'devuelto') {
      return res.status(400).json({
        ok: false,
        mensaje: 'Este préstamo ya fue devuelto previamente.'
      });
    }

    const hoy = new Date().toISOString().split('T')[0];

    // 1. Registrar en tabla devoluciones
    const devolucion = await Devolucion.create({
      id_prestamo: prestamo.id_prestamo,
      fecha_devolucion: hoy,
      observaciones
    });

    // 2. Actualizar préstamo a 'devuelto'
    prestamo.estado = 'devuelto';
    prestamo.fecha_devolucion = hoy;
    await prestamo.save();

    // 3. Actualizar ejemplar a 'disponible' y condición física si se envía
    const ejemplar = await Ejemplar.findByPk(prestamo.id_ejemplar);
    if (ejemplar) {
      ejemplar.disponibilidad = 'disponible';
      if (condicion && ['bueno', 'regular'].includes(condicion)) {
        ejemplar.condicion = condicion;
      }
      await ejemplar.save();
    }

    return res.json({
      ok: true,
      mensaje: 'Devolución registrada exitosamente. El ejemplar está nuevamente disponible.',
      devolucion,
      prestamo,
      ejemplar
    });
  } catch (error) {
    console.error('Error al registrar devolución:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al procesar la devolución.',
      error: error.message
    });
  }
};

const misPrestamos = async (req, res) => {
  try {
    const id_usuario = req.usuario.id_usuario;
    const [prestamos, solicitudes] = await Promise.all([
      Prestamo.findAll({
        where: { id_usuario },
        include: [
          { model: Libro, as: 'libro' },
          { model: Ejemplar, as: 'ejemplar' },
          { model: Devolucion, as: 'devolucion' }
        ],
        order: [['id_prestamo', 'DESC']]
      }),
      Solicitud.findAll({
        where: { id_usuario },
        include: [
          {
            model: Ejemplar,
            as: 'ejemplar',
            include: [{ model: Libro, as: 'libro' }]
          }
        ],
        order: [['id_solicitud', 'DESC']]
      })
    ]);

    const solicitudesPendientesORechazadas = solicitudes
      .filter((s) => s.estado !== 'aprobada')
      .map((s) => {
        const json = s.toJSON();
        return {
          id_prestamo: json.id_solicitud,
          id_solicitud: json.id_solicitud,
          id_usuario: json.id_usuario,
          id_ejemplar: json.id_ejemplar,
          libro: json.ejemplar ? json.ejemplar.libro : null,
          ejemplar: json.ejemplar || null,
          fecha_prestamo: 'Solicitud enviada',
          fecha_devolucion: null,
          estado: json.estado
        };
      });

    return res.json([...solicitudesPendientesORechazadas, ...prestamos]);
  } catch (error) {
    console.error('Error al consultar mis préstamos:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al obtener el historial de préstamos.',
      error: error.message
    });
  }
};

const misSolicitudes = async (req, res) => {
  try {
    const id_usuario = req.usuario.id_usuario;
    const solicitudes = await Solicitud.findAll({
      where: { id_usuario },
      include: [
        {
          model: Ejemplar,
          as: 'ejemplar',
          include: [{ model: Libro, as: 'libro' }]
        }
      ],
      order: [['id_solicitud', 'DESC']]
    });

    return res.json(solicitudes);
  } catch (error) {
    console.error('Error al consultar mis solicitudes:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al obtener tus solicitudes.',
      error: error.message
    });
  }
};

const listarTodosLosPrestamos = async (req, res) => {
  try {
    const prestamos = await Prestamo.findAll({
      include: [
        { model: Usuario, as: 'usuario' },
        { model: Libro, as: 'libro' },
        { model: Ejemplar, as: 'ejemplar' },
        { model: Devolucion, as: 'devolucion' }
      ],
      order: [['id_prestamo', 'DESC']]
    });

    return res.json(prestamos);
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al listar los préstamos.',
      error: error.message
    });
  }
};

module.exports = {
  crearSolicitud,
  listarSolicitudes,
  aprobarSolicitud,
  rechazarSolicitud,
  registrarDevolucion,
  misPrestamos,
  misSolicitudes,
  listarTodosLosPrestamos
};
