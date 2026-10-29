const express = require('express');
const router = express.Router();
const solicitudController = require('../controllers/solicitudController');
const { verificarToken, esAdmin } = require('../middlewares/authMiddleware');

// Lista los préstamos pendientes (solo administrador)
const listarPendientes = (req, res, next) => {
  req.query.estado = 'pendiente';
  return solicitudController.listarSolicitudes(req, res, next);
};

// Estudiante/Profesor autenticado: solicitar un préstamo (queda en estado 'pendiente')
router.post('/', verificarToken, solicitudController.crearSolicitud);

// Historial del usuario autenticado
router.get('/mis-prestamos', verificarToken, solicitudController.misPrestamos);

// Administrador: ver pendientes, aprobar o rechazar
router.get('/pendientes', verificarToken, esAdmin, listarPendientes);
router.put('/:id/aprobar', verificarToken, esAdmin, solicitudController.aprobarSolicitud);
router.put('/:id/rechazar', verificarToken, esAdmin, solicitudController.rechazarSolicitud);

// Administrador: listado general y devoluciones (si se pasa ?estado=pendiente lista pendientes)
router.get('/', verificarToken, esAdmin, (req, res, next) => {
  if (req.query.estado === 'pendiente') {
    return listarPendientes(req, res, next);
  }
  return solicitudController.listarTodosLosPrestamos(req, res, next);
});
router.post('/:id/devolver', verificarToken, esAdmin, solicitudController.registrarDevolucion);

module.exports = router;
