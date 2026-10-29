const { Op } = require('sequelize');
const { Libro, Ejemplar, Solicitud, Prestamo, Devolucion } = require('../models');

// Listar libros y calcular stock disponible desde la base de datos
const listarLibros = async (req, res) => {
  try {
    const { titulo, autor, area } = req.query;
    const whereClause = {};

    if (titulo) {
      whereClause.titulo = { [Op.iLike]: `%${titulo.trim()}%` };
    }
    if (autor) {
      whereClause.autor = { [Op.iLike]: `%${autor.trim()}%` };
    }
    if (area) {
      whereClause.area = { [Op.iLike]: `%${area.trim()}%` };
    }

    const libros = await Libro.findAll({
      where: whereClause,
      include: [
        {
          model: Ejemplar,
          as: 'ejemplares'
        }
      ],
      order: [['id_libro', 'ASC']]
    });

    const librosConStock = libros.map((libro) => {
      const json = libro.toJSON();
      const ejemplares = json.ejemplares || [];
      json.total_ejemplares = ejemplares.length;
      json.ejemplares_disponibles = ejemplares.filter(
        (e) => e.disponibilidad === 'disponible'
      ).length;
      return json;
    });

    return res.json(librosConStock);
  } catch (error) {
    console.error('Error al listar libros:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al obtener el catálogo de libros.',
      error: error.message
    });
  }
};

const listarEjemplaresPorLibro = async (req, res) => {
  try {
    const { id } = req.params;
    const libro = await Libro.findByPk(id, {
      include: [{ model: Ejemplar, as: 'ejemplares' }]
    });

    if (!libro) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Libro no encontrado.'
      });
    }

    return res.json({
      ok: true,
      libro: {
        id_libro: libro.id_libro,
        codigo_libro: libro.codigo_libro,
        titulo: libro.titulo,
        autor: libro.autor
      },
      ejemplares: libro.ejemplares
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al obtener ejemplares.',
      error: error.message
    });
  }
};

// ============================================================================
// CRUD DE ADMINISTRACIÓN DE LIBROS (CREAR Y ELIMINAR)
// ============================================================================

// Registrar un nuevo libro junto con sus ejemplares físicos en Supabase
const crearLibro = async (req, res) => {
  try {
    const { titulo, autor, area, stock, cantidad, anio_publicacion, codigo_libro } = req.body;

    if (!titulo || !autor || !area) {
      return res.status(400).json({
        ok: false,
        mensaje: 'Título, autor y área son obligatorios.'
      });
    }

    const cantidadStock = parseInt(stock ?? cantidad ?? 1, 10);
    const numEjemplares = isNaN(cantidadStock) || cantidadStock < 1 ? 1 : cantidadStock;
    const anio = parseInt(anio_publicacion || new Date().getFullYear(), 10);

    // Generar un código único para el libro si no fue provisto
    let codLibro = codigo_libro ? String(codigo_libro).trim() : null;
    if (!codLibro) {
      const timestamp = Date.now().toString().slice(-5);
      const random = Math.floor(100 + Math.random() * 900);
      codLibro = `LIB-${timestamp}-${random}`;
    }

    // 1. Crear el libro en la base de datos
    const nuevoLibro = await Libro.create({
      codigo_libro: codLibro,
      titulo: titulo.trim(),
      autor: autor.trim(),
      area: area.trim(),
      anio_publicacion: isNaN(anio) ? new Date().getFullYear() : anio
    });

    // 2. Crear los ejemplares físicos correspondientes al stock
    const ejemplaresCreados = [];
    for (let i = 1; i <= numEjemplares; i++) {
      const codigoInv = `INV-${nuevoLibro.id_libro}-${i}-${Date.now().toString().slice(-4)}`;
      const nuevoEjemplar = await Ejemplar.create({
        id_libro: nuevoLibro.id_libro,
        codigo_inventario: codigoInv,
        condicion: 'bueno',
        disponibilidad: 'disponible'
      });
      ejemplaresCreados.push(nuevoEjemplar);
    }

    return res.status(201).json({
      ok: true,
      mensaje: `Libro "${nuevoLibro.titulo}" registrado exitosamente con ${ejemplaresCreados.length} ejemplar(es).`,
      libro: {
        ...nuevoLibro.toJSON(),
        ejemplares: ejemplaresCreados,
        total_ejemplares: ejemplaresCreados.length,
        ejemplares_disponibles: ejemplaresCreados.length
      }
    });
  } catch (error) {
    console.error('Error al crear libro:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error interno al registrar el libro y sus ejemplares.',
      error: error.message
    });
  }
};

const editarLibro = async (req, res) => {
  try {
    const { id } = req.params;
    const { titulo, autor, area, anio_publicacion } = req.body;

    const libro = await Libro.findByPk(id);
    if (!libro) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Libro no encontrado.'
      });
    }

    await libro.update({
      titulo: titulo ? titulo.trim() : libro.titulo,
      autor: autor ? autor.trim() : libro.autor,
      area: area ? area.trim() : libro.area,
      anio_publicacion: anio_publicacion ? parseInt(anio_publicacion, 10) : libro.anio_publicacion
    });

    return res.json({
      ok: true,
      mensaje: 'Libro actualizado correctamente.',
      libro
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al actualizar libro.',
      error: error.message
    });
  }
};

// Eliminar un libro por ID junto con sus ejemplares y relaciones dependientes
const eliminarLibro = async (req, res) => {
  try {
    const { id } = req.params;

    const libro = await Libro.findByPk(id, {
      include: [{ model: Ejemplar, as: 'ejemplares' }]
    });

    if (!libro) {
      return res.status(404).json({
        ok: false,
        mensaje: `No se encontró el libro con ID ${id}.`
      });
    }

    const ejemplares = libro.ejemplares || [];
    const idEjemplares = ejemplares.map((e) => e.id_ejemplar);

    // Limpiar préstamos y solicitudes previas asociadas para prevenir violaciones de clave foránea
    if (idEjemplares.length > 0) {
      if (Devolucion) {
        try {
          const prestamosRelacionados = await Prestamo.findAll({
            where: { id_ejemplar: { [Op.in]: idEjemplares } },
            attributes: ['id_prestamo']
          });
          const idsPrestamos = prestamosRelacionados.map((p) => p.id_prestamo);
          if (idsPrestamos.length > 0) {
            await Devolucion.destroy({ where: { id_prestamo: { [Op.in]: idsPrestamos } } });
          }
        } catch (e) {
          console.warn('Advertencia al limpiar devoluciones:', e.message);
        }
      }

      await Prestamo.destroy({
        where: {
          [Op.or]: [
            { id_libro: id },
            { id_ejemplar: { [Op.in]: idEjemplares } }
          ]
        }
      }).catch(() => {});

      await Solicitud.destroy({
        where: { id_ejemplar: { [Op.in]: idEjemplares } }
      }).catch(() => {});

      await Ejemplar.destroy({
        where: { id_libro: id }
      });
    } else {
      await Prestamo.destroy({ where: { id_libro: id } }).catch(() => {});
    }

    // Destruir el libro
    await libro.destroy();

    return res.json({
      ok: true,
      mensaje: `Libro "${libro.titulo}" eliminado exitosamente.`
    });
  } catch (error) {
    console.error('Error al eliminar libro:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al eliminar el libro.',
      error: error.message
    });
  }
};

// Aumentar el stock de un libro existente insertando automáticamente nuevos ejemplares disponibles
const aumentarStock = async (req, res) => {
  try {
    const id_libro = req.params.id || req.body.id_libro;
    const cantidad = parseInt(req.body.cantidad || req.body.stock || 1, 10);

    if (!id_libro) {
      return res.status(400).json({
        ok: false,
        mensaje: 'El id_libro es obligatorio.'
      });
    }

    if (isNaN(cantidad) || cantidad <= 0) {
      return res.status(400).json({
        ok: false,
        mensaje: 'La cantidad a aumentar debe ser un número entero mayor a 0.'
      });
    }

    // Verificar existencia del libro
    const libro = await Libro.findByPk(id_libro, {
      include: [{ model: Ejemplar, as: 'ejemplares' }]
    });

    if (!libro) {
      return res.status(404).json({
        ok: false,
        mensaje: `No se encontró el libro con ID ${id_libro}.`
      });
    }

    const ejemplaresActuales = libro.ejemplares || [];
    const baseCount = ejemplaresActuales.length;

    // Crear la cantidad solicitada de nuevos ejemplares disponibles con su código de inventario
    const nuevosEjemplares = [];
    for (let i = 1; i <= cantidad; i++) {
      const codigoInv = `INV-${libro.id_libro}-${baseCount + i}-${Date.now().toString().slice(-4)}`;
      const nuevoEjemplar = await Ejemplar.create({
        id_libro: libro.id_libro,
        codigo_inventario: codigoInv,
        condicion: 'bueno',
        disponibilidad: 'disponible'
      });
      nuevosEjemplares.push(nuevoEjemplar);
    }

    // Recalcular stock total y disponible
    const ejemplaresTotales = await Ejemplar.findAll({
      where: { id_libro: libro.id_libro }
    });
    const disponibles = ejemplaresTotales.filter((e) => e.disponibilidad === 'disponible').length;

    return res.status(200).json({
      ok: true,
      mensaje: `Se agregaron exitosamente ${nuevosEjemplares.length} nuevo(s) ejemplar(es) al libro "${libro.titulo}".`,
      nuevos_ejemplares: nuevosEjemplares,
      total_ejemplares: ejemplaresTotales.length,
      ejemplares_disponibles: disponibles,
      libro: {
        id_libro: libro.id_libro,
        titulo: libro.titulo,
        total_ejemplares: ejemplaresTotales.length,
        ejemplares_disponibles: disponibles
      }
    });
  } catch (error) {
    console.error('Error al aumentar stock:', error);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error interno al aumentar el stock del libro.',
      error: error.message
    });
  }
};

module.exports = {
  listarLibros,
  listarEjemplaresPorLibro,
  crearLibro,
  editarLibro,
  eliminarLibro,
  aumentarStock
};
