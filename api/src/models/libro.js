const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Libro = sequelize.define('libros', {
  id_libro: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  codigo_libro: {
    type: DataTypes.STRING(50),
    allowNull: false,
    unique: true
  },
  titulo: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  autor: {
    type: DataTypes.STRING(150),
    allowNull: false
  },
  area: {
    type: DataTypes.STRING(100),
    allowNull: false
  },
  anio_publicacion: {
    type: DataTypes.INTEGER,
    allowNull: false
  }
}, {
  timestamps: false,
  freezeTableName: true
});

module.exports = Libro;
