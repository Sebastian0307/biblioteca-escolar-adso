const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { verificarToken } = require('../middlewares/authMiddleware');

router.post('/login', authController.login);
router.post('/register', authController.register);
router.post('/change-password', verificarToken, authController.cambiarContrasena);
router.patch('/change-password', verificarToken, authController.cambiarContrasena);
router.post('/seed', authController.seed);
router.get('/perfil', verificarToken, authController.perfil);

module.exports = router;
