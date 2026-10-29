const express = require('express');
const router = express.Router();
const libroController = require('../controllers/libroController');

// Consulta de catálogo y stock para préstamos
router.get('/', libroController.listarLibros);
router.get('/:id/ejemplares', libroController.listarEjemplaresPorLibro);

// Rutas CRUD de administración de libros (crear, editar, eliminar)
router.post('/', libroController.crearLibro);
router.put('/:id', libroController.editarLibro);
router.delete('/:id', libroController.eliminarLibro);

// Aumentar stock de un libro existente (inserta nuevos ejemplares disponibles)
router.post('/aumentar-stock', libroController.aumentarStock);
router.post('/:id/aumentar-stock', libroController.aumentarStock);
router.post('/:id/stock', libroController.aumentarStock);
router.post('/:id/ejemplares', libroController.aumentarStock);

module.exports = router;
