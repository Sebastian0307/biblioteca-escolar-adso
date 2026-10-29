const sequelize = require('../config/database');
const Usuario = require('./usuario');
const Login = require('./login');
const Libro = require('./libro');
const Ejemplar = require('./ejemplar');
const Solicitud = require('./solicitud');
const Prestamo = require('./prestamo');
const Devolucion = require('./devolucion');

module.exports = {
  sequelize,
  Usuario,
  Login,
  Libro,
  Ejemplar,
  Solicitud,
  Prestamo,
  Devolucion
};
