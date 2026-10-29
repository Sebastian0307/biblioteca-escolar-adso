const express = require('express');
const router = express.Router();
const solicitudController = require('../controllers/solicitudController');
const { verificarToken } = require('../middlewares/authMiddleware');

router.get('/mis-prestamos', verificarToken, solicitudController.misPrestamos);
router.get('/mis-solicitudes', verificarToken, solicitudController.misSolicitudes);
router.get('/prestamos', verificarToken, solicitudController.listarTodosLosPrestamos);

router.post('/', verificarToken, solicitudController.crearSolicitud);
router.get('/', verificarToken, solicitudController.listarSolicitudes);
router.patch('/:id/approve', verificarToken, solicitudController.aprobarSolicitud);
router.put('/:id/approve', verificarToken, solicitudController.aprobarSolicitud);
router.patch('/:id/reject', verificarToken, solicitudController.rechazarSolicitud);
router.post('/:id/devolver', verificarToken, solicitudController.registrarDevolucion);

module.exports = router;
