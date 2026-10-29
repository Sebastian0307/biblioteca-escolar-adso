const jwt = require('jsonwebtoken');
require('dotenv').config();

const verificarToken = (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'] || req.headers['Authorization'];
    if (!authHeader) {
      return res.status(401).json({
        ok: false,
        mensaje: 'Acceso denegado. No se proporcionó token de autenticación.'
      });
    }

    const partes = authHeader.split(' ');
    const token = partes.length === 2 && partes[0].toLowerCase() === 'bearer' ? partes[1] : authHeader;

    if (!token) {
      return res.status(401).json({
        ok: false,
        mensaje: 'Formato de token inválido. Use Authorization: Bearer <token>'
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secreto_super_seguro_sena_2026');
    req.usuario = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      ok: false,
      mensaje: 'Token inválido o expirado.',
      error: error.message
    });
  }
};

const esAdmin = (req, res, next) => {
  const tipo = (req.usuario?.tipo_usuario || '').toLowerCase();
  const rol = (req.usuario?.rol || '').toLowerCase();

  const esAdministrador =
    tipo === 'administrador' ||
    tipo === 'administrativo' ||
    rol === 'admin' ||
    rol === 'administrador';

  if (!req.usuario || !esAdministrador) {
    return res.status(403).json({
      ok: false,
      mensaje: 'Acceso restringido. Se requieren permisos de administrador.'
    });
  }
  next();
};

module.exports = verificarToken;
module.exports.verificarToken = verificarToken;
module.exports.esAdmin = esAdmin;
