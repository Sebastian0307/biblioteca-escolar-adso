const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const Usuario = require('./usuario');
const Libro = require('./libro');
const Ejemplar = require('./ejemplar');

const Prestamo = sequelize.define('prestamos', {
  id_prestamo: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  id_usuario: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Usuario,
      key: 'id_usuario'
    }
  },
  id_libro: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Libro,
      key: 'id_libro'
    }
  },
  id_ejemplar: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: Ejemplar,
      key: 'id_ejemplar'
    }
  },
  fecha_prestamo: {
    type: DataTypes.DATEONLY,
    allowNull: false,
    defaultValue: DataTypes.NOW
  },
  fecha_devolucion: {
    type: DataTypes.DATEONLY,
    allowNull: true
  },
  estado: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'activo',
    validate: {
      isIn: [['activo', 'devuelto']]
    }
  }
}, {
  timestamps: false,
  freezeTableName: true
});

Usuario.hasMany(Prestamo, { foreignKey: 'id_usuario', as: 'prestamos', onDelete: 'CASCADE' });
Prestamo.belongsTo(Usuario, { foreignKey: 'id_usuario', as: 'usuario' });

Libro.hasMany(Prestamo, { foreignKey: 'id_libro', as: 'prestamos', onDelete: 'CASCADE' });
Prestamo.belongsTo(Libro, { foreignKey: 'id_libro', as: 'libro' });

Ejemplar.hasMany(Prestamo, { foreignKey: 'id_ejemplar', as: 'prestamos', onDelete: 'CASCADE' });
Prestamo.belongsTo(Ejemplar, { foreignKey: 'id_ejemplar', as: 'ejemplar' });

module.exports = Prestamo;
