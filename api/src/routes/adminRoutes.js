const express = require('express');
const router = express.Router();
const multer = require('multer');
const adminController = require('../controllers/adminController');
const { verificarToken } = require('../middlewares/authMiddleware');

const upload = multer({ storage: multer.memoryStorage() });

router.get('/usuarios', verificarToken, adminController.listarUsuarios);
router.post('/usuarios', verificarToken, adminController.crearUsuario);
router.patch('/usuarios/:id', verificarToken, adminController.actualizarUsuario);
router.delete('/usuarios/:id', verificarToken, adminController.eliminarUsuario);
router.get('/usuarios/plantilla-excel', adminController.descargarPlantillaExcel);
router.post('/usuarios/upload-excel', verificarToken, upload.any(), adminController.cargarUsuariosExcel);

module.exports = router;
